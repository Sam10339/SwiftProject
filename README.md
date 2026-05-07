# HabitQuest SwiftUI

HabitQuest is a native iOS habit-tracking app built with SwiftUI. The app turns daily routines into a gamified experience where users create habits, earn XP, maintain streaks, unlock achievements, review progress analytics, and manage their profile. Firebase Authentication and Cloud Firestore are used for account login and cloud data storage.

This README is written for the final project submission and explains what was completed, how the project works, how to run it, database usage, current limitations, unfinished features, and future plans.

## Completed Project

HabitQuest includes the following completed app flows:

- Splash screen and onboarding flow
- Email/password sign up and sign in
- Password reset email support
- Dashboard with today's habits, XP gained, XP lost, completion progress, and motivational copy
- Habit creation with icon, category, frequency, and optional reminder time
- Habit detail page with stats and calendar-style progress
- Manual habit completion and manual habit failure
- Automatic missed-day tracking after the daily completion window expires
- XP gain for completed habits and XP loss for failed/missed habits
- Auto-pause after 3 consecutive missed habit days
- Resume button for paused habits
- Analytics page with weekly activity, monthly completion, success rate, net XP, XP gained, and XP lost
- Rewards page with achievement progress, claimable achievements, and finished achievements
- Achievement XP must be claimed by tapping an unlocked achievement
- Completed/claimed achievements cannot be claimed again
- Profile page with actual recent unlocked achievements
- Edit Profile page for changing display name and sending password reset email
- Privacy & Security page with an app-store-ready privacy statement
- Sign out support
- Firestore persistence for signed-in users

## Source Code

The main project files are in:

```text
HabitQuest Mobile App UI/
```

Important source files:

- `HabitQuest/HabitQuestApp.swift` - App entry point and Firebase bootstrap.
- `HabitQuest/ContentView.swift` - SwiftUI screens, navigation, cards, buttons, and UI components.
- `HabitQuest/AppModel.swift` - Main app state, habit logic, XP logic, achievements, missed-day tracking, pause/resume logic, and profile actions.
- `HabitQuest/AuthManager.swift` - Firebase Authentication wrapper.
- `HabitQuest/CloudDataManager.swift` - Firestore load/save logic and database mapping.
- `HabitQuest/SampleData.swift` - Local sample data used for previews/starter state.
- `HabitQuest/Theme.swift` - Shared colors, gradients, layout values, and formatters.

## How the App Works

### User Accounts

Users create an account or sign in with email and password. Firebase Authentication manages account credentials. The app also supports password reset emails through Firebase.

### Habits

Users can create habits with:

- Name
- Icon
- Category
- Frequency
- Optional reminder time

Each habit has an XP value based on its category. Completing a habit adds XP. Failing or missing a habit subtracts XP using the habit's penalty value.

### Time Tracking and Auto-Fail

Each habit stores a creation date and tracks completed and missed dates.

For daily habits, if the habit is not completed within its daily window, the app marks it as missed and subtracts XP. If a user misses 3 days in a row, the habit automatically pauses. Paused habits cannot be completed or failed until the user resumes them.

### Achievements

Achievements unlock when users meet progress requirements such as completing a first habit, reaching streak goals, or completing multiple habits in one day.

Unlocked achievements do not automatically give XP. The user must tap the unlocked achievement to claim the XP reward. Once claimed, the achievement moves to the Finished Achievements section and cannot be claimed again.

### Analytics

The analytics page summarizes performance using:

- Weekly habit completion
- Monthly completion percentages
- Success rate
- Net XP this week
- Total XP gained
- Total XP lost

### Profile

The profile page displays user level, XP progress, stats, recent unlocked achievements, settings, and sign out. The Edit Profile page allows the user to change their display name and send a password reset email. The Privacy & Security page explains how account and habit data are handled.

## Database

HabitQuest uses Firebase Cloud Firestore as the database.

### Firestore Structure

Each user is stored under the `users` collection:

```text
users/{userID}
```

The user document stores profile-level data:

```text
name
email
totalXP
level
currentXP
xpToNextLevel
totalHabitsCompleted
longestStreak
avatar
lastDailyRefreshDate
updatedAt
```

Each user has a `habits` subcollection:

```text
users/{userID}/habits/{habitID}
```

Habit documents store:

```text
name
icon
category
frequency
streak
completed
xp
createdAt
isPaused
pausedAt
completionHistory
missedHistory
reminderEnabled
reminderTime
updatedAt
```

Each user also has an `achievements` subcollection:

```text
users/{userID}/achievements/{achievementID}
```

Achievement documents store:

```text
title
description
icon
unlocked
claimed
unlockedAt
progress
total
xpReward
updatedAt
```

## Setup and Run Instructions

### Requirements

- macOS
- Xcode
- iOS Simulator or physical iPhone
- Firebase project
- Firebase Authentication enabled
- Cloud Firestore enabled

### Run the Project

1. Open Xcode.
2. Open:

   ```text
   HabitQuest Mobile App UI/HabitQuest.xcodeproj
   ```

3. Select the `HabitQuest` scheme.
4. Select an iPhone simulator or connected iPhone.
5. Run the app.

### Firebase Setup

1. Create a Firebase project in the Firebase console.
2. Add an iOS app in Firebase.
3. Use the bundle ID:

   ```text
   com.habitquest.swiftui
   ```

   Or update the Xcode bundle ID to match your Firebase app.

4. Enable `Authentication > Sign-in method > Email/Password`.
5. Create a Cloud Firestore database.
6. Download `GoogleService-Info.plist`.
7. Add `GoogleService-Info.plist` to the `HabitQuest` target in Xcode.
8. Let Xcode resolve Swift Package dependencies for Firebase.

### Dependencies

The app uses Swift Package Manager packages for:

- FirebaseAuth
- FirebaseFirestore

# Project Progress Videos

Sprint 1 video:
https://drive.google.com/file/d/17Hq_0A0ofw4dykGEwQaXocHcZQtStEG5/view?usp=sharing 

Sprint 2 video:
https://drive.google.com/file/d/1lXEwVPqzjDkK5YPYDL-2N5vMmucVA0rE/view?usp=sharing 

Sprint 3 video:
https://drive.google.com/file/d/18DQE58N8g5TjLG3wZLi6ndNsn8znVmmu/view?usp=sharing 

Sprint 4 video:
https://drive.google.com/file/d/1jy9Qd-CbDNtdki910JRRiHSZz7ZC6PO4/view?usp=sharing 

Sprint 5 video: 
https://drive.google.com/file/d/1I19lWMkLoVcyP2bIFlIR0bJp12osy0Rp/view?usp=sharing 

Sprint 6 video:
https://drive.google.com/file/d/1lO6Mh7UXq9ClpATqGAmQH3OT6slYK0SO/view?usp=sharing 

## Limitations

- Notifications are not implemented yet, even though habits can store a reminder time.
- Email changes are not fully implemented in the UI. Password reset is supported instead.
- The app depends on Firebase being configured correctly for authentication and cloud sync.
- Offline support is limited. Starter data can load if Firestore is unavailable, but a full offline sync/conflict system is not implemented.
- Automatic missed-day tracking runs when the app/session refreshes state, not through a background server job.
- The reminder time is stored but does not currently schedule local push notifications.
- The project does not currently include automated unit tests or UI tests.
- Some analytics are calculated from available habit history and are not advanced statistical reports.

## Features Not Completed

These items were planned or considered but were not completed for the final version:

- Push notifications for habit reminders
- Full email change flow
- In-app password change form
- Custom avatar/profile image upload
- Level reward unlock system
- Themes or custom app color rewards
- Social sharing or friend leaderboards
- Advanced calendar editing for past habit results
- Automated test suite

## Future Plans

Future versions of HabitQuest could include:

- Local notifications for reminders
- More detailed habit schedules such as custom days, every other day, or multiple times per day
- Full account settings for changing email and password inside the app
- Custom profile avatars
- More achievement types and achievement categories
- Level-based rewards such as themes, badges, icons, or cosmetic profile upgrades
- Streak recovery or forgiveness tokens
- Better offline support with automatic sync when connection returns
- Export progress data as CSV or PDF
- App Store privacy policy link and terms of service page
- Widget support for quick habit completion
- Apple Sign In
- Unit tests for XP, missed-day, achievement, and pause/resume logic
- UI tests for login, habit creation, achievement claiming, and profile editing

## Project Status

HabitQuest is feature-complete for the current class project goals. The app supports the core habit-tracking workflow, gamified XP progression, achievements, analytics, profile management, Firebase authentication, and Firestore persistence. Remaining work is primarily polish, notification support, deeper account settings, and future expansion features.


