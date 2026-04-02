import Combine
import Foundation

enum AppPhase {
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
    var completionHistory: [String]
    var reminderEnabled: Bool
    var reminderTime: String?

    var totalEarnedXP: Int {
        completionHistory.count * xp
    }
}

struct Achievement: Identifiable, Hashable {
    let id: String
    var title: String
    var description: String
    var icon: String
    var unlocked: Bool
    var progress: Int?
    var total: Int?
    var xpReward: Int
}

struct UserProfile: Hashable {
    var name: String
    var level: Int
    var currentXP: Int
    var xpToNextLevel: Int
    var totalHabitsCompleted: Int
    var longestStreak: Int
    var avatar: String
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
    @Published var authErrorMessage: String?
    @Published var authInfoMessage: String?

    let isFirebaseConfigured: Bool

    private let authManager: AuthManaging
    private let userDefaults: UserDefaults

    init(
        habits: [Habit] = SampleData.habits,
        achievements: [Achievement] = SampleData.achievements,
        userProfile: UserProfile = SampleData.userProfile,
        authManager: AuthManaging = FirebaseAuthManager(),
        userDefaults: UserDefaults = .standard
    ) {
        self.habits = habits
        self.achievements = achievements
        self.userProfile = userProfile
        self.authManager = authManager
        self.userDefaults = userDefaults
        self.isFirebaseConfigured = authManager.isConfigured
        self.authEmail = authManager.currentUserEmail ?? ""

        authManager.observeAuthChanges { [weak self] email in
            guard let self else { return }
            Task { @MainActor in
                self.authEmail = email ?? ""
                if self.hasCompletedOnboarding {
                    self.phase = email == nil ? .login : .main
                }
            }
        }
    }

    var todayLabel: String {
        QuestFormatters.dayHeader.string(from: .now)
    }

    var xpProgress: Double {
        guard userProfile.xpToNextLevel > 0 else { return 0 }
        return min(Double(userProfile.currentXP) / Double(userProfile.xpToNextLevel), 1)
    }

    var completedHabitsCount: Int {
        habits.filter(\.completed).count
    }

    var dailyCompletionPercentage: Int {
        guard !habits.isEmpty else { return 0 }
        return Int((Double(completedHabitsCount) / Double(habits.count) * 100).rounded())
    }

    var totalXPToday: Int {
        habits.filter(\.completed).reduce(0) { $0 + $1.xp }
    }

    var unlockedAchievementsCount: Int {
        achievements.filter(\.unlocked).count
    }

    var achievementCompletionPercentage: Int {
        guard !achievements.isEmpty else { return 0 }
        return Int((Double(unlockedAchievementsCount) / Double(achievements.count) * 100).rounded())
    }

    var totalAchievementBonusXP: Int {
        achievements.filter(\.unlocked).reduce(0) { $0 + $1.xpReward }
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

    var displayName: String {
        guard !authEmail.isEmpty else { return userProfile.name }
        return authEmail.components(separatedBy: "@").first ?? userProfile.name
    }

    func completeSplash() {
        phase = hasCompletedOnboarding ? (authEmail.isEmpty ? .login : .main) : .onboarding
    }

    func finishOnboarding() {
        userDefaults.set(true, forKey: Keys.hasCompletedOnboarding)
        phase = authEmail.isEmpty ? .login : .main
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
            let email = try await authManager.signIn(email: cleanedEmail, password: cleanedPassword, isSignUp: isSignUp)
            authEmail = email ?? cleanedEmail
            phase = .main
            selectedTab = .dashboard
            path = []
        } catch {
            authErrorMessage = Self.message(from: error)
        }
    }

    func sendPasswordReset(email: String) async {
        authErrorMessage = nil
        authInfoMessage = nil

        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard isFirebaseConfigured else {
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

    func toggleHabit(id: String) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }

        let wasCompleted = habits[index].completed
        habits[index].completed.toggle()

        if wasCompleted {
            userProfile.currentXP = max(0, userProfile.currentXP - habits[index].xp)
            userProfile.totalHabitsCompleted = max(0, userProfile.totalHabitsCompleted - 1)
        } else {
            userProfile.currentXP = min(userProfile.xpToNextLevel, userProfile.currentXP + habits[index].xp)
            userProfile.totalHabitsCompleted += 1
        }
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
            completionHistory: [],
            reminderEnabled: draft.reminderEnabled,
            reminderTime: timeLabel
        )

        habits.insert(newHabit, at: 0)
        selectedTab = .dashboard
    }

    func deleteHabit(id: String) {
        habits.removeAll { $0.id == id }
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

    private static func message(from error: Error) -> String {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }

        return error.localizedDescription
    }
}
