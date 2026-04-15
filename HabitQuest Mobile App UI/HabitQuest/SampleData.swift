import Foundation

enum SampleData {
    static let habits: [Habit] = [
        Habit(
            id: "1",
            name: "Morning Meditation",
            icon: "\u{1F9D8}",
            category: "Health",
            frequency: "Daily",
            streak: 15,
            completed: true,
            xp: 50,
            completionHistory: ["2026-03-11", "2026-03-10", "2026-03-09", "2026-03-08"],
            missedHistory: [],
            reminderEnabled: true,
            reminderTime: "07:00"
        ),
        Habit(
            id: "2",
            name: "Read for 30 min",
            icon: "\u{1F4DA}",
            category: "Learning",
            frequency: "Daily",
            streak: 8,
            completed: false,
            xp: 40,
            completionHistory: ["2026-03-10", "2026-03-09", "2026-03-08"],
            missedHistory: [],
            reminderEnabled: true,
            reminderTime: "20:00"
        ),
        Habit(
            id: "3",
            name: "Drink 8 Glasses Water",
            icon: "\u{1F4A7}",
            category: "Health",
            frequency: "Daily",
            streak: 22,
            completed: true,
            xp: 30,
            completionHistory: ["2026-03-11", "2026-03-10", "2026-03-09"],
            missedHistory: [],
            reminderEnabled: false,
            reminderTime: nil
        ),
        Habit(
            id: "4",
            name: "Exercise",
            icon: "\u{1F4AA}",
            category: "Fitness",
            frequency: "Daily",
            streak: 5,
            completed: false,
            xp: 60,
            completionHistory: ["2026-03-10", "2026-03-09"],
            missedHistory: [],
            reminderEnabled: true,
            reminderTime: "18:00"
        ),
        Habit(
            id: "5",
            name: "Code Practice",
            icon: "\u{1F4BB}",
            category: "Productivity",
            frequency: "Daily",
            streak: 12,
            completed: true,
            xp: 70,
            completionHistory: ["2026-03-11", "2026-03-10", "2026-03-09"],
            missedHistory: [],
            reminderEnabled: true,
            reminderTime: "14:00"
        )
    ]

    static let achievements: [Achievement] = [
        Achievement(id: "1", title: "First Step", description: "Complete your first habit", icon: "\u{1F3AF}", unlocked: true, progress: nil, total: nil, xpReward: 100),
        Achievement(id: "2", title: "Week Warrior", description: "Maintain a 7-day streak", icon: "\u{26A1}", unlocked: true, progress: nil, total: nil, xpReward: 250),
        Achievement(id: "3", title: "Consistency King", description: "Maintain a 30-day streak", icon: "\u{1F451}", unlocked: false, progress: 15, total: 30, xpReward: 500),
        Achievement(id: "4", title: "Habit Master", description: "Complete 100 habits total", icon: "\u{1F3C6}", unlocked: false, progress: 45, total: 100, xpReward: 1000),
        Achievement(id: "5", title: "Early Bird", description: "Complete a habit before 8 AM for 7 days", icon: "\u{1F305}", unlocked: true, progress: nil, total: nil, xpReward: 300),
        Achievement(id: "6", title: "Multi-tasker", description: "Complete 5 habits in a single day", icon: "\u{1F3AA}", unlocked: false, progress: 3, total: 5, xpReward: 400)
    ]

    static let userProfile = UserProfile(
        name: "Alex Johnson",
        level: 8,
        currentXP: 2340,
        xpToNextLevel: 3000,
        totalHabitsCompleted: 156,
        longestStreak: 22,
        avatar: "\u{1F464}",
        lastDailyRefreshDate: "2026-03-11"
    )

    static let motivationalMessages = [
        "Every small step counts! Keep going! \u{1F31F}",
        "You're building amazing habits! \u{1F4AA}",
        "Consistency is key to success! \u{1F511}",
        "Today is a great day to grow! \u{1F331}",
        "One day at a time, you've got this! \u{1F3AF}"
    ]

    static let habitIconOptions = [
        "\u{1F9D8}",
        "\u{1F4DA}",
        "\u{1F4A7}",
        "\u{1F4AA}",
        "\u{1F4BB}",
        "\u{1F3A8}",
        "\u{1F3C3}",
        "\u{1F3AF}",
        "\u{1F331}",
        "\u{1F3B5}",
        "\u{270D}\u{FE0F}",
        "\u{1F34E}"
    ]

    static let categories = [
        "Health",
        "Fitness",
        "Learning",
        "Productivity",
        "Mindfulness",
        "Creativity"
    ]

    static let frequencies = [
        "Daily",
        "Weekly",
        "Weekdays",
        "Weekends"
    ]

    static let weeklyActivity = [
        WeeklyActivityPoint(day: "Mon", completed: 4, total: 5),
        WeeklyActivityPoint(day: "Tue", completed: 5, total: 5),
        WeeklyActivityPoint(day: "Wed", completed: 3, total: 5),
        WeeklyActivityPoint(day: "Thu", completed: 4, total: 5),
        WeeklyActivityPoint(day: "Fri", completed: 5, total: 5),
        WeeklyActivityPoint(day: "Sat", completed: 4, total: 5),
        WeeklyActivityPoint(day: "Sun", completed: 3, total: 5)
    ]

    static let monthlyCompletion = [
        MonthlyCompletionPoint(week: "Week 1", percentage: 85),
        MonthlyCompletionPoint(week: "Week 2", percentage: 92),
        MonthlyCompletionPoint(week: "Week 3", percentage: 78),
        MonthlyCompletionPoint(week: "Week 4", percentage: 88)
    ]

    static let onboardingSteps = [
        OnboardingStepModel(
            title: "Welcome to\nHabitQuest",
            description: "Transform your daily routines into an epic adventure. Build better habits and level up your life!",
            icon: "\u{1F3AE}",
            gradient: QuestPalette.primaryGradient,
            features: []
        ),
        OnboardingStepModel(
            title: "Earn XP &\nLevel Up",
            description: "Complete habits to earn experience points. Watch yourself grow stronger every day!",
            icon: "\u{26A1}",
            gradient: QuestPalette.blueGradient,
            features: [
                OnboardingFeature(symbolName: "bolt.fill", text: "Gain XP for each completed habit"),
                OnboardingFeature(symbolName: "chart.line.uptrend.xyaxis", text: "Level up and unlock rewards")
            ]
        ),
        OnboardingStepModel(
            title: "Build Epic\nStreaks",
            description: "Maintain daily streaks to multiply your progress. Consistency is your superpower!",
            icon: "\u{1F525}",
            gradient: QuestPalette.orangeGradient,
            features: [
                OnboardingFeature(symbolName: "sparkles", text: "Track your daily streaks"),
                OnboardingFeature(symbolName: "trophy.fill", text: "Unlock special achievements")
            ]
        ),
        OnboardingStepModel(
            title: "Start Your\nJourney",
            description: "Ready to become the best version of yourself? Your quest begins now!",
            icon: "\u{1F680}",
            gradient: QuestPalette.purplePinkGradient,
            features: []
        )
    ]
}
