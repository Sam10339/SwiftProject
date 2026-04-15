import Foundation
import FirebaseCore
import FirebaseFirestore

private let firestoreContinuationError = NSError(
    domain: "HabitQuest.Firestore",
    code: -1,
    userInfo: [NSLocalizedDescriptionKey: "Firestore returned an unexpected empty response."]
)

struct UserCloudSnapshot {
    var profile: UserProfile
    var habits: [Habit]
    var achievements: [Achievement]
}

enum CloudDataError: LocalizedError {
    case firestoreNotConfigured

    var errorDescription: String? {
        switch self {
        case .firestoreNotConfigured:
            return "Firestore isn't configured yet. Add Firebase to the project and make sure Firestore is enabled in the Firebase console."
        }
    }
}

protocol CloudDataManaging {
    var isConfigured: Bool { get }

    func loadOrCreateUserSnapshot(userID: String, email: String?) async throws -> UserCloudSnapshot
    func saveUserSnapshot(userID: String, email: String?, snapshot: UserCloudSnapshot) async throws
    func deleteHabit(userID: String, habitID: String) async throws
}

final class FirestoreDataManager: CloudDataManaging {
    var isConfigured: Bool {
        FirebaseApp.app() != nil
    }

    private var db: Firestore {
        Firestore.firestore()
    }

    func loadOrCreateUserSnapshot(userID: String, email: String?) async throws -> UserCloudSnapshot {
        guard isConfigured else {
            throw CloudDataError.firestoreNotConfigured
        }

        let userRef = db.collection("users").document(userID)
        let userDocument = try await userRef.codexGetDocument()
        let habitDocuments = try await userRef.collection("habits").codexGetDocuments()
        let achievementDocuments = try await userRef.collection("achievements").codexGetDocuments()

        if !userDocument.exists && habitDocuments.documents.isEmpty && achievementDocuments.documents.isEmpty {
            let starterSnapshot = UserCloudSnapshot.starter(email: email)
            try await saveUserSnapshot(userID: userID, email: email, snapshot: starterSnapshot)
            return starterSnapshot
        }

        let profile = UserProfile(documentData: userDocument.data(), fallbackEmail: email)

        let habits = habitDocuments.documents
            .map(Habit.init(document:))
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let achievements = achievementDocuments.documents
            .map(Achievement.init(document:))
            .sorted { $0.id < $1.id }

        let fallback = UserCloudSnapshot.starter(email: email)
        return UserCloudSnapshot(
            profile: profile,
            habits: habits,
            achievements: achievements.isEmpty ? fallback.achievements : achievements
        )
    }

    func saveUserSnapshot(userID: String, email: String?, snapshot: UserCloudSnapshot) async throws {
        guard isConfigured else {
            throw CloudDataError.firestoreNotConfigured
        }

        let userRef = db.collection("users").document(userID)
        let batch = db.batch()

        batch.setData(snapshot.profile.firestoreData(email: email), forDocument: userRef, merge: true)

        for habit in snapshot.habits {
            batch.setData(habit.firestoreData, forDocument: userRef.collection("habits").document(habit.id), merge: true)
        }

        for achievement in snapshot.achievements {
            batch.setData(achievement.firestoreData, forDocument: userRef.collection("achievements").document(achievement.id), merge: true)
        }

        try await batch.codexCommit()
    }

    func deleteHabit(userID: String, habitID: String) async throws {
        guard isConfigured else {
            throw CloudDataError.firestoreNotConfigured
        }

        try await db.collection("users").document(userID).collection("habits").document(habitID).codexDelete()
    }
}

extension UserCloudSnapshot {
    static func starter(email: String?) -> UserCloudSnapshot {
        UserCloudSnapshot(
            profile: UserProfile.starter(email: email),
            habits: [],
            achievements: Achievement.starterSet
        )
    }
}

extension UserProfile {
    static func starter(email: String?) -> UserProfile {
        UserProfile(
            name: Self.defaultName(for: email),
            level: 1,
            currentXP: 0,
            xpToNextLevel: 300,
            totalHabitsCompleted: 0,
            longestStreak: 0,
            avatar: "\u{1F464}",
            lastDailyRefreshDate: nil
        )
    }

    init(documentData: [String: Any]?, fallbackEmail: String?) {
        let starter = Self.starter(email: fallbackEmail)
        let data = documentData ?? [:]

        self.init(
            name: data["name"] as? String ?? starter.name,
            level: data["level"] as? Int ?? starter.level,
            currentXP: data["currentXP"] as? Int ?? starter.currentXP,
            xpToNextLevel: data["xpToNextLevel"] as? Int ?? starter.xpToNextLevel,
            totalHabitsCompleted: data["totalHabitsCompleted"] as? Int ?? starter.totalHabitsCompleted,
            longestStreak: data["longestStreak"] as? Int ?? starter.longestStreak,
            avatar: data["avatar"] as? String ?? starter.avatar,
            lastDailyRefreshDate: data["lastDailyRefreshDate"] as? String
        )
    }

    func firestoreData(email: String?) -> [String: Any] {
        [
            "name": name,
            "email": email ?? NSNull(),
            "level": level,
            "currentXP": currentXP,
            "xpToNextLevel": xpToNextLevel,
            "totalHabitsCompleted": totalHabitsCompleted,
            "longestStreak": longestStreak,
            "avatar": avatar,
            "lastDailyRefreshDate": lastDailyRefreshDate ?? NSNull(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    private static func defaultName(for email: String?) -> String {
        guard let email, let localPart = email.split(separator: "@").first else {
            return "Habit Hero"
        }

        let tokens = localPart.split(whereSeparator: { $0 == "." || $0 == "_" || $0 == "-" })
        let normalized = tokens.map { token in
            token.prefix(1).uppercased() + token.dropFirst().lowercased()
        }

        return normalized.isEmpty ? "Habit Hero" : normalized.joined(separator: " ")
    }
}

private extension Habit {
    init(document: QueryDocumentSnapshot) {
        let data = document.data()
        self.init(
            id: document.documentID,
            name: data["name"] as? String ?? "Untitled Habit",
            icon: data["icon"] as? String ?? "\u{1F4DD}",
            category: data["category"] as? String ?? "Health",
            frequency: data["frequency"] as? String ?? "Daily",
            streak: data["streak"] as? Int ?? 0,
            completed: data["completed"] as? Bool ?? false,
            xp: data["xp"] as? Int ?? 30,
            completionHistory: data["completionHistory"] as? [String] ?? [],
            missedHistory: data["missedHistory"] as? [String] ?? [],
            reminderEnabled: data["reminderEnabled"] as? Bool ?? false,
            reminderTime: data["reminderTime"] as? String
        )
    }

    var firestoreData: [String: Any] {
        [
            "name": name,
            "icon": icon,
            "category": category,
            "frequency": frequency,
            "streak": streak,
            "completed": completed,
            "xp": xp,
            "completionHistory": completionHistory,
            "missedHistory": missedHistory,
            "reminderEnabled": reminderEnabled,
            "reminderTime": reminderTime ?? NSNull(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

extension Achievement {
    static var starterSet: [Achievement] {
        [
            Achievement(id: "1", title: "First Step", description: "Complete your first habit", icon: "\u{1F3AF}", unlocked: false, progress: 0, total: 1, xpReward: 100),
            Achievement(id: "2", title: "Week Warrior", description: "Maintain a 7-day streak", icon: "\u{26A1}", unlocked: false, progress: 0, total: 7, xpReward: 250),
            Achievement(id: "3", title: "Consistency King", description: "Maintain a 30-day streak", icon: "\u{1F451}", unlocked: false, progress: 0, total: 30, xpReward: 500),
            Achievement(id: "4", title: "Habit Master", description: "Complete 100 habits total", icon: "\u{1F3C6}", unlocked: false, progress: 0, total: 100, xpReward: 1000),
            Achievement(id: "5", title: "Early Bird", description: "Complete a habit before 8 AM for 7 days", icon: "\u{1F305}", unlocked: false, progress: 0, total: 7, xpReward: 300),
            Achievement(id: "6", title: "Multi-tasker", description: "Complete 5 habits in a single day", icon: "\u{1F3AA}", unlocked: false, progress: 0, total: 5, xpReward: 400)
        ]
    }

    init(document: QueryDocumentSnapshot) {
        let data = document.data()
        self.init(
            id: document.documentID,
            title: data["title"] as? String ?? "Achievement",
            description: data["description"] as? String ?? "",
            icon: data["icon"] as? String ?? "\u{1F3C6}",
            unlocked: data["unlocked"] as? Bool ?? false,
            progress: data["progress"] as? Int,
            total: data["total"] as? Int,
            xpReward: data["xpReward"] as? Int ?? 0
        )
    }

    var firestoreData: [String: Any] {
        [
            "title": title,
            "description": description,
            "icon": icon,
            "unlocked": unlocked,
            "progress": progress ?? NSNull(),
            "total": total ?? NSNull(),
            "xpReward": xpReward,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

private extension DocumentReference {
    func codexGetDocument() async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: firestoreContinuationError)
                }
            }
        }
    }

    func codexDelete() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

private extension CollectionReference {
    func codexGetDocuments() async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { continuation in
            getDocuments { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: firestoreContinuationError)
                }
            }
        }
    }
}

private extension WriteBatch {
    func codexCommit() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            commit { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
