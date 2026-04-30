import Combine
import Foundation
import FirebaseFirestore

enum AppPhase: Equatable {
    case splash
    case onboarding
    case login
    case main
}

enum MainTab: String, CaseIterable, Hashable {
    case dashboard
    case analytics
    case achievements
    case profile

    var title: String {
        switch self {
        case .dashboard:
            return "Home"
        case .analytics:
            return "Progress"
        case .achievements:
            return "Rewards"
        case .profile:
            return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "house.fill"
        case .analytics:
            return "chart.line.uptrend.xyaxis"
        case .achievements:
            return "trophy.fill"
        case .profile:
            return "person.fill"
        }
    }
}

enum AppDestination: Hashable {
    case addHabit
    case habitDetail(String)
}

struct Habit: Identifiable, Hashable {
    let id: String
    var name: String
    var icon: String
    var category: String
    var frequency: String
    var streak: Int
    var completed: Bool
    var xp: Int
    var createdAt: Date
    var isPaused: Bool
    var pausedAt: Date?
    var completionHistory: [String]
    var missedHistory: [String]
    var reminderEnabled: Bool
    var reminderTime: String?

    var totalEarnedXP: Int {
        completionHistory.count * xp
    }

    var xpPenalty: Int {
        xp / 2
    }

    var totalLostXP: Int {
        missedHistory.count * xpPenalty
    }

    var consecutiveMisses: Int {
        let trackingStart = Calendar.current.startOfDay(for: createdAt)
        return Habit.currentConsecutiveDays(in: missedHistory, since: trackingStart)
    }

    private static func currentConsecutiveDays(in history: [String], since startDate: Date) -> Int {
        let uniqueDates = Set(history.compactMap(HabitQuestStore.date(fromDayKey:)).filter { $0 >= startDate })
        guard let latestDate = uniqueDates.max() else { return 0 }

        var streak = 0
        var cursor = latestDate

        while uniqueDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: cursor) }) {
            streak += 1
            guard let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }

        return streak
    }
}

struct Achievement: Identifiable, Hashable {
    let id: String
    var title: String
    var description: String
    var icon: String
    var unlocked: Bool
    var claimed: Bool
    var progress: Int?
    var total: Int?
    var xpReward: Int
}

struct UserProfile: Hashable {
    var name: String
    var totalXP: Int
    var level: Int
    var currentXP: Int
    var xpToNextLevel: Int
    var totalHabitsCompleted: Int
    var longestStreak: Int
    var avatar: String
    var lastDailyRefreshDate: String?
}

struct HabitDraft {
    var name: String = ""
    var icon: String = "\u{1F9D8}"
    var category: String = "Health"
    var frequency: String = "Daily"
    var reminderEnabled: Bool = false
    var reminderTime: Date = HabitDraft.defaultReminderTime

    static var defaultReminderTime: Date {
        Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? .now
    }
}

struct WeeklyActivityPoint: Identifiable, Hashable {
    let day: String
    let completed: Int
    let total: Int

    var id: String { day }
}

struct MonthlyCompletionPoint: Identifiable, Hashable {
    let week: String
    let percentage: Int

    var id: String { week }
}

struct OnboardingFeature: Hashable {
    let symbolName: String
    let text: String
}

struct OnboardingStepModel: Hashable {
    let title: String
    let description: String
    let icon: String
    let gradient: QuestGradientSet
    let features: [OnboardingFeature]
}

enum QuestLeveling {
    static let maxLevel = 50
    static let baseXPRequirement = 300
    static let xpRequirementStep = 75

    static func xpRequired(for level: Int) -> Int {
        guard level > 0 else { return baseXPRequirement }
        return baseXPRequirement + max(level - 1, 0) * xpRequirementStep
    }

    static func state(for totalXP: Int) -> (level: Int, currentXP: Int, xpToNextLevel: Int) {
        var remainingXP = max(totalXP, 0)
        var level = 1

        while level < maxLevel {
            let requirement = xpRequired(for: level)
            if remainingXP < requirement {
                return (level, remainingXP, requirement)
            }

            remainingXP -= requirement
            level += 1
        }

        return (maxLevel, 0, xpRequired(for: maxLevel - 1))
    }

    static func totalXP(forLevel level: Int, currentXP: Int) -> Int {
        let clampedLevel = min(max(level, 1), maxLevel)
        let earnedBeforeCurrentLevel = (1..<clampedLevel).reduce(0) { partialResult, level in
            partialResult + xpRequired(for: level)
        }

        guard clampedLevel < maxLevel else {
            return earnedBeforeCurrentLevel
        }

        return earnedBeforeCurrentLevel + min(max(currentXP, 0), xpRequired(for: clampedLevel))
    }
}

@MainActor
final class HabitQuestStore: ObservableObject {
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    @Published var phase: AppPhase = .splash
    @Published var selectedTab: MainTab = .dashboard
    @Published var path: [AppDestination] = []
    @Published var habits: [Habit]
    @Published var achievements: [Achievement]
    @Published var userProfile: UserProfile
    @Published var authEmail: String = ""
    @Published var isAuthenticating = false
    @Published var isSyncingRemoteData = false
    @Published var authErrorMessage: String?
    @Published var authInfoMessage: String?

    let isFirebaseConfigured: Bool

    private let authManager: AuthManaging
    private let cloudDataManager: CloudDataManaging
    private let userDefaults: UserDefaults

    private var activeUserID: String?
    private var persistenceTask: Task<Void, Never>?

    init(
        habits: [Habit] = SampleData.habits,
        achievements: [Achievement] = SampleData.achievements,
        userProfile: UserProfile = SampleData.userProfile,
        authManager: AuthManaging = FirebaseAuthManager(),
        cloudDataManager: CloudDataManaging = FirestoreDataManager(),
        userDefaults: UserDefaults = .standard
    ) {
        self.habits = habits
        self.achievements = achievements
        self.userProfile = userProfile
        self.authManager = authManager
        self.cloudDataManager = cloudDataManager
        self.userDefaults = userDefaults
        self.isFirebaseConfigured = authManager.isConfigured && cloudDataManager.isConfigured
        self.authEmail = authManager.currentSession?.email ?? ""
        self.activeUserID = authManager.currentSession?.userID

        authManager.observeAuthChanges { [weak self] session in
            guard let self else { return }
            Task { @MainActor in
                await self.handleAuthStateChange(session)
            }
        }

        refreshDerivedState()
    }

    var todayLabel: String {
        QuestFormatters.dayHeader.string(from: .now)
    }

    var xpProgress: Double {
        if isAtMaxLevel {
            return 1
        }

        guard userProfile.xpToNextLevel > 0 else { return 0 }
        return min(Double(userProfile.currentXP) / Double(userProfile.xpToNextLevel), 1)
    }

    var isAtMaxLevel: Bool {
        userProfile.level >= QuestLeveling.maxLevel
    }

    var nextLevelTitle: String {
        isAtMaxLevel ? "Max Level Reached" : "Progress to Level \(userProfile.level + 1)"
    }

    var xpProgressLabel: String {
        isAtMaxLevel ? "MAX" : "\(userProfile.currentXP) / \(userProfile.xpToNextLevel) XP"
    }

    var xpRemainingToNextLevel: Int {
        guard !isAtMaxLevel else { return 0 }
        return max(userProfile.xpToNextLevel - userProfile.currentXP, 0)
    }

    var completedHabitsCount: Int {
        habits.filter { $0.completed && !$0.isPaused }.count
    }

    var dailyCompletionPercentage: Int {
        let activeHabits = habits.filter { !$0.isPaused }
        guard !activeHabits.isEmpty else { return 0 }
        return Int((Double(completedHabitsCount) / Double(activeHabits.count) * 100).rounded())
    }

    var totalXPToday: Int {
        habits.filter { $0.completed && !$0.isPaused }.reduce(0) { $0 + $1.xp }
    }

    var xpGainedToday: Int {
        let todayKey = Self.dayKey(for: .now)
        return habits.reduce(0) { partialResult, habit in
            partialResult + (habit.completionHistory.contains(todayKey) ? habit.xp : 0)
        }
    }

    var xpLostToday: Int {
        let todayKey = Self.dayKey(for: .now)
        return habits.reduce(0) { partialResult, habit in
            partialResult + (habit.missedHistory.contains(todayKey) ? habit.xpPenalty : 0)
        }
    }

    var totalXPGained: Int {
        habits.reduce(0) { $0 + $1.totalEarnedXP }
    }

    var totalXPLost: Int {
        habits.reduce(0) { $0 + $1.totalLostXP }
    }

    var weeklyNetXP: Int {
        let recentKeys = Set(Self.dayKeys(forLast: 7))
        return habits.reduce(0) { partialResult, habit in
            let gained = habit.completionHistory.filter { recentKeys.contains($0) }.count * habit.xp
            let lost = habit.missedHistory.filter { recentKeys.contains($0) }.count * habit.xpPenalty
            return partialResult + gained - lost
        }
    }

    var successRate: Int {
        let totalCompleted = habits.reduce(0) { $0 + $1.completionHistory.count }
        let totalMissed = habits.reduce(0) { $0 + $1.missedHistory.count }
        let totalTrackedDays = totalCompleted + totalMissed
        guard totalTrackedDays > 0 else { return 0 }
        return Int((Double(totalCompleted) / Double(totalTrackedDays) * 100).rounded())
    }

    var weeklyActivity: [WeeklyActivityPoint] {
        let dates = Self.dates(forLast: 7)

        return dates.map { date in
            let dayKey = Self.dayKey(for: date)
            let scheduled = habits.filter { Self.habit($0, shouldTrackOn: date) }
            let completed = scheduled.filter { $0.completionHistory.contains(dayKey) }.count

            return WeeklyActivityPoint(
                day: QuestFormatters.weekdayShort.string(from: date),
                completed: completed,
                total: scheduled.count
            )
        }
    }

    var monthlyCompletion: [MonthlyCompletionPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return (0..<4).reversed().map { index in
            let weekOffset = index * 7
            let endDate = calendar.date(byAdding: .day, value: -weekOffset, to: today) ?? today
            let startDate = calendar.date(byAdding: .day, value: -6, to: endDate) ?? endDate
            let weekDates = Self.dateRange(from: startDate, through: endDate)

            var completed = 0
            var total = 0

            for date in weekDates {
                let dayKey = Self.dayKey(for: date)
                for habit in habits where Self.habit(habit, shouldTrackOn: date) {
                    total += 1
                    if habit.completionHistory.contains(dayKey) {
                        completed += 1
                    }
                }
            }

            let percentage = total == 0 ? 0 : Int((Double(completed) / Double(total) * 100).rounded())
            return MonthlyCompletionPoint(week: "Week \(4 - index)", percentage: percentage)
        }
    }

    var unlockedAchievementsCount: Int {
        achievements.filter(\.unlocked).count
    }

    var finishedAchievementsCount: Int {
        achievements.filter(\.claimed).count
    }

    var claimableAchievements: [Achievement] {
        achievements.filter { $0.unlocked && !$0.claimed }
    }

    var finishedAchievements: [Achievement] {
        achievements.filter(\.claimed)
    }

    var achievementCompletionPercentage: Int {
        guard !achievements.isEmpty else { return 0 }
        return Int((Double(finishedAchievementsCount) / Double(achievements.count) * 100).rounded())
    }

    var totalAchievementBonusXP: Int {
        achievements.filter(\.claimed).reduce(0) { $0 + $1.xpReward }
    }

    var averageStreak: Int {
        guard !habits.isEmpty else { return 0 }
        return Int((Double(habits.reduce(0) { $0 + $1.streak }) / Double(habits.count)).rounded())
    }

    var motivationalMessage: String {
        let dayIndex = max((Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1) - 1, 0)
        return SampleData.motivationalMessages[dayIndex % SampleData.motivationalMessages.count]
    }

    var hasCompletedOnboarding: Bool {
        userDefaults.bool(forKey: Keys.hasCompletedOnboarding)
    }

    var todayKey: String {
        Self.dayKey(for: .now)
    }

    var displayName: String {
        guard !userProfile.name.isEmpty else {
            return authEmail.components(separatedBy: "@").first ?? "Habit Hero"
        }

        return userProfile.name
    }

    func completeSplash() {
        guard hasCompletedOnboarding else {
            phase = .onboarding
            return
        }

        if authManager.currentSession == nil {
            phase = .login
        }
    }

    func finishOnboarding() {
        userDefaults.set(true, forKey: Keys.hasCompletedOnboarding)
        phase = authManager.currentSession == nil ? .login : .main
    }

    func signIn(email: String, password: String, isSignUp: Bool) async {
        authErrorMessage = nil
        authInfoMessage = nil

        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isFirebaseConfigured else {
            authErrorMessage = AuthError.firebaseNotConfigured.errorDescription
            return
        }

        guard !cleanedEmail.isEmpty, !cleanedPassword.isEmpty else {
            authErrorMessage = AuthError.emptyCredentials.errorDescription
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let session = try await authManager.signIn(email: cleanedEmail, password: cleanedPassword, isSignUp: isSignUp)
            await loadRemoteData(for: session)
        } catch {
            authErrorMessage = Self.message(from: error)
        }
    }

    func sendPasswordReset(email: String) async {
        authErrorMessage = nil
        authInfoMessage = nil

        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard authManager.isConfigured else {
            authErrorMessage = AuthError.firebaseNotConfigured.errorDescription
            return
        }

        guard !cleanedEmail.isEmpty else {
            authErrorMessage = AuthError.missingResetEmail.errorDescription
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            try await authManager.sendPasswordReset(email: cleanedEmail)
            authInfoMessage = "Password reset email sent to \(cleanedEmail)."
        } catch {
            authErrorMessage = Self.message(from: error)
        }
    }

    func signOut() {
        authErrorMessage = nil
        authInfoMessage = nil

        do {
            try authManager.signOut()
            resetLocalData()
            activeUserID = nil
            authEmail = ""
            phase = .login
            selectedTab = .dashboard
            path = []
        } catch {
            authErrorMessage = Self.message(from: error)
        }
    }

    func showAddHabit() {
        path.append(.addHabit)
    }

    func showHabitDetail(id: String) {
        path.append(.habitDetail(id))
    }

    func habit(withID id: String) -> Habit? {
        habits.first(where: { $0.id == id })
    }

    func completeHabit(id: String) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }

        var habit = habits[index]
        guard !habit.isPaused else { return }

        let todayKey = self.todayKey

        guard !habit.completionHistory.contains(todayKey) else { return }

        if habit.missedHistory.contains(todayKey) {
            habit.missedHistory.removeAll { $0 == todayKey }
            awardXP(habit.xpPenalty)
        }

        habit.completed = true
        habit.completionHistory.append(todayKey)
        awardXP(habit.xp)

        habit.completionHistory = Self.sortedHistory(habit.completionHistory)
        habit.missedHistory = Self.sortedHistory(habit.missedHistory)
        habit.streak = Self.currentStreak(for: habit.completionHistory)
        habits[index] = habit

        refreshDerivedState()
        schedulePersistCurrentUserState()
    }

    func failHabit(id: String) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }

        var habit = habits[index]
        guard !habit.isPaused else { return }

        let todayKey = self.todayKey

        guard !habit.missedHistory.contains(todayKey) else { return }

        if habit.completionHistory.contains(todayKey) {
            habit.completionHistory.removeAll { $0 == todayKey }
            removeXP(habit.xp)
        }

        habit.completed = false
        habit.missedHistory.append(todayKey)

        if habit.xpPenalty > 0 {
            removeXP(habit.xpPenalty)
        }

        habit.completionHistory = Self.sortedHistory(habit.completionHistory)
        habit.missedHistory = Self.sortedHistory(habit.missedHistory)
        habit.isPaused = habit.consecutiveMisses >= 3
        habit.pausedAt = habit.isPaused ? .now : nil
        habit.streak = Self.currentStreak(for: habit.completionHistory)
        habits[index] = habit

        refreshDerivedState()
        schedulePersistCurrentUserState()
    }

    func resumeHabit(id: String) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        guard habits[index].isPaused else { return }

        habits[index].isPaused = false
        habits[index].pausedAt = nil
        habits[index].createdAt = .now
        refreshDerivedState()
        schedulePersistCurrentUserState()
    }

    func addHabit(from draft: HabitDraft) {
        let timeLabel = draft.reminderEnabled ? QuestFormatters.timeOnly.string(from: draft.reminderTime) : nil
        let rewardXP = xpValue(for: draft.category)

        let newHabit = Habit(
            id: UUID().uuidString,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: draft.icon,
            category: draft.category,
            frequency: draft.frequency,
            streak: 0,
            completed: false,
            xp: rewardXP,
            createdAt: .now,
            isPaused: false,
            pausedAt: nil,
            completionHistory: [],
            missedHistory: [],
            reminderEnabled: draft.reminderEnabled,
            reminderTime: timeLabel
        )

        habits.insert(newHabit, at: 0)
        selectedTab = .dashboard
        refreshDerivedState()
        schedulePersistCurrentUserState()
    }

    func deleteHabit(id: String) {
        habits.removeAll { $0.id == id }
        refreshDerivedState()

        guard let userID = activeUserID else { return }

        persistenceTask?.cancel()
        persistenceTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.cloudDataManager.deleteHabit(userID: userID, habitID: id)
                try await self.persistCurrentUserState()
            } catch {
                await MainActor.run {
                    self.authErrorMessage = Self.message(from: error)
                }
            }
        }
    }

    func claimAchievement(id: String) {
        guard let index = achievements.firstIndex(where: { $0.id == id }) else { return }
        guard achievements[index].unlocked && !achievements[index].claimed else { return }

        achievements[index].claimed = true
        achievements[index].progress = nil
        awardXP(achievements[index].xpReward)
        schedulePersistCurrentUserState()
    }

    private func handleAuthStateChange(_ session: AuthSession?) async {
        authEmail = session?.email ?? ""

        guard let session else {
            activeUserID = nil
            resetLocalData()
            if hasCompletedOnboarding && phase != .splash {
                phase = .login
            }
            return
        }

        guard hasCompletedOnboarding else { return }

        if activeUserID != session.userID || phase == .splash {
            await loadRemoteData(for: session)
        } else if phase != .main {
            phase = .main
        }
    }

    private func loadRemoteData(for session: AuthSession) async {
        guard isFirebaseConfigured else {
            authErrorMessage = CloudDataError.firestoreNotConfigured.errorDescription
            return
        }

        isSyncingRemoteData = true
        authErrorMessage = nil
        authInfoMessage = nil

        defer { isSyncingRemoteData = false }

        do {
            let snapshot = try await cloudDataManager.loadOrCreateUserSnapshot(userID: session.userID, email: session.email)
            activeUserID = session.userID
            authEmail = session.email ?? ""
            userProfile = snapshot.profile
            habits = snapshot.habits
            achievements = snapshot.achievements
            refreshDerivedState()
            selectedTab = .dashboard
            path = []
            if hasCompletedOnboarding {
                phase = .main
            }
        } catch {
            if Self.isFirestoreOffline(error) {
                let starterSnapshot = UserCloudSnapshot.starter(email: session.email)
                activeUserID = session.userID
                authEmail = session.email ?? ""
                userProfile = starterSnapshot.profile
                habits = starterSnapshot.habits
                achievements = starterSnapshot.achievements
                selectedTab = .dashboard
                path = []
                if hasCompletedOnboarding {
                    phase = .main
                }
                authInfoMessage = "Your account was created, but Firestore is offline right now. You're using starter data until the app can reconnect."
            } else {
                authErrorMessage = Self.message(from: error)
            }
        }
    }

    private func persistCurrentUserState() async throws {
        guard let userID = activeUserID else { return }

        let snapshot = UserCloudSnapshot(profile: userProfile, habits: habits, achievements: achievements)
        try await cloudDataManager.saveUserSnapshot(userID: userID, email: authEmail, snapshot: snapshot)
    }

    private func schedulePersistCurrentUserState() {
        guard activeUserID != nil else { return }

        persistenceTask?.cancel()
        persistenceTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await self.persistCurrentUserState()
            } catch {
                await MainActor.run {
                    self.authErrorMessage = Self.message(from: error)
                }
            }
        }
    }

    private func resetLocalData() {
        habits = []
        achievements = Achievement.starterSet
        userProfile = UserProfile(name: "", totalXP: 0, level: 1, currentXP: 0, xpToNextLevel: QuestLeveling.xpRequired(for: 1), totalHabitsCompleted: 0, longestStreak: 0, avatar: "\u{1F464}", lastDailyRefreshDate: Self.dayKey(for: .now))
    }

    private func refreshDerivedState() {
        applyMissedHabitPenaltiesIfNeeded()

        habits = habits.map { habit in
            var habit = habit
            habit.completionHistory = Self.sortedHistory(habit.completionHistory)
            habit.missedHistory = Self.sortedHistory(habit.missedHistory)
            habit.streak = Self.currentStreak(for: habit.completionHistory)
            habit.isPaused = habit.isPaused || habit.consecutiveMisses >= 3
            habit.completed = !habit.isPaused && habit.completionHistory.contains(Self.dayKey(for: .now))
            return habit
        }

        userProfile.totalHabitsCompleted = habits.reduce(0) { $0 + $1.completionHistory.count }
        userProfile.longestStreak = habits.map(\.streak).max() ?? 0
        recalculateLevelState()
        updateAchievements()
    }

    private func updateAchievements() {
        let todayCompletedCount = habits.filter(\.completed).count
        let longestStreak = userProfile.longestStreak
        let totalCompleted = userProfile.totalHabitsCompleted
        let earlyBirdProgress = habits.filter {
            $0.reminderEnabled && ($0.reminderTime ?? "99:99") < "08:00" && $0.completed
        }.count

        achievements = achievements.map { achievement in
            let target = achievement.total ?? 1
            let progress: Int

            switch achievement.id {
            case "1":
                progress = totalCompleted
            case "2":
                progress = longestStreak
            case "3":
                progress = longestStreak
            case "4":
                progress = totalCompleted
            case "5":
                progress = earlyBirdProgress
            case "6":
                progress = todayCompletedCount
            default:
                progress = achievement.progress ?? 0
            }

            let cappedProgress = min(progress, target)
            let shouldUnlock = achievement.claimed || achievement.unlocked || progress >= target
            return Achievement(
                id: achievement.id,
                title: achievement.title,
                description: achievement.description,
                icon: achievement.icon,
                unlocked: shouldUnlock,
                claimed: achievement.claimed,
                progress: shouldUnlock ? nil : cappedProgress,
                total: achievement.total,
                xpReward: achievement.xpReward
            )
        }
    }

    private func awardXP(_ amount: Int) {
        guard amount > 0 else { return }
        userProfile.totalXP += amount
        recalculateLevelState()
    }

    private func removeXP(_ amount: Int) {
        guard amount > 0 else { return }
        userProfile.totalXP = max(userProfile.totalXP - amount, 0)
        recalculateLevelState()
    }

    private func recalculateLevelState() {
        let state = QuestLeveling.state(for: userProfile.totalXP)
        userProfile.level = state.level
        userProfile.currentXP = state.currentXP
        userProfile.xpToNextLevel = state.xpToNextLevel
    }

    private func applyMissedHabitPenaltiesIfNeeded() {
        let calendar = Calendar.current
        let now = Date.now
        let today = calendar.startOfDay(for: now)
        let todayKey = Self.dayKey(for: today)

        guard let dayBeforeToday = calendar.date(byAdding: .day, value: -1, to: today) else {
            userProfile.lastDailyRefreshDate = todayKey
            return
        }

        for index in habits.indices where !habits[index].isPaused {
            var cursor = calendar.startOfDay(for: habits[index].createdAt)

            while cursor <= dayBeforeToday {
                let dayKey = Self.dayKey(for: cursor)
                let shouldTrack = Self.habit(habits[index], shouldTrackOn: cursor)
                let deadlinePassed = now >= Self.deadline(for: habits[index], on: cursor)
                let isUnlogged = !habits[index].completionHistory.contains(dayKey) && !habits[index].missedHistory.contains(dayKey)

                if shouldTrack && deadlinePassed && isUnlogged {
                    habits[index].missedHistory.append(dayKey)
                    removeXP(habits[index].xpPenalty)

                    if habits[index].consecutiveMisses >= 3 {
                        habits[index].isPaused = true
                        habits[index].pausedAt = now
                        break
                    }
                }

                cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? dayBeforeToday.addingTimeInterval(1)
            }
        }

        userProfile.lastDailyRefreshDate = todayKey
    }

    private func xpValue(for category: String) -> Int {
        switch category {
        case "Fitness":
            return 60
        case "Learning":
            return 40
        case "Productivity":
            return 70
        case "Mindfulness":
            return 50
        case "Creativity":
            return 45
        default:
            return 30
        }
    }

    private static func currentStreak(for history: [String]) -> Int {
        let uniqueDates = Set(history.compactMap(Self.dateFormatter.date(from:)))
        guard let latestDate = uniqueDates.max() else { return 0 }

        var streak = 0
        var cursor = latestDate

        while uniqueDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: cursor) }) {
            streak += 1
            guard let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }

        return streak
    }

    private static func sortedHistory(_ history: [String]) -> [String] {
        Array(Set(history)).sorted(by: >)
    }

    private static func dayKey(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func date(fromDayKey dayKey: String) -> Date? {
        dateFormatter.date(from: dayKey)
    }

    private static func dayKeys(forLast count: Int) -> [String] {
        dates(forLast: count).map(dayKey(for:))
    }

    private static func dates(forLast count: Int) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: -(count - 1 - offset), to: today)
        }
    }

    private static func dateRange(from startDate: Date, through endDate: Date) -> [Date] {
        var dates: [Date] = []
        var cursor = Calendar.current.startOfDay(for: startDate)
        let finalDate = Calendar.current.startOfDay(for: endDate)

        while cursor <= finalDate {
            dates.append(cursor)
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor) ?? finalDate.addingTimeInterval(1)
        }

        return dates
    }

    private static func habit(_ habit: Habit, shouldTrackOn date: Date) -> Bool {
        guard !habit.isPaused else { return false }

        switch habit.frequency {
        case "Weekly":
            let calendar = Calendar.current
            return calendar.component(.weekday, from: date) == calendar.component(.weekday, from: habit.createdAt)
        case "Weekdays":
            return !Calendar.current.isDateInWeekend(date)
        case "Weekends":
            return Calendar.current.isDateInWeekend(date)
        default:
            return true
        }
    }

    private static func deadline(for habit: Habit, on date: Date) -> Date {
        let calendar = Calendar.current
        let scheduledDay = calendar.startOfDay(for: date)
        let creationDay = calendar.startOfDay(for: habit.createdAt)

        if calendar.isDate(scheduledDay, inSameDayAs: creationDay) {
            return calendar.date(byAdding: .hour, value: 24, to: habit.createdAt) ?? scheduledDay.addingTimeInterval(86_400)
        }

        return calendar.date(byAdding: .day, value: 1, to: scheduledDay) ?? scheduledDay.addingTimeInterval(86_400)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func message(from error: Error) -> String {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }

        return error.localizedDescription
    }

    private static func isFirestoreOffline(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == FirestoreErrorDomain
            && nsError.code == FirestoreErrorCode.unavailable.rawValue
    }
}
