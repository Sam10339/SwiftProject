# HabitQuest SwiftUI

This folder now contains a native SwiftUI version of HabitQuest that preserves the original splash, onboarding, login, dashboard, analytics, achievements, profile, add-habit, and habit-detail flows.

## Open the app

Open `HabitQuest.xcodeproj` in Xcode and run the `HabitQuest` scheme on an iPhone or iPad simulator.

## Firebase auth setup

The app now includes Firebase email/password auth wiring in code.

To finish setup:

1. Create a Firebase project in the Firebase console.
2. Add an iOS app with the bundle ID `com.habitquest.swiftui` or update the Xcode bundle ID to match your Firebase app.
3. Enable `Authentication > Sign-in method > Email/Password`.
4. Download `GoogleService-Info.plist`.
5. Drag `GoogleService-Info.plist` into the `HabitQuest` target in Xcode.
6. Let Xcode resolve the Swift Package dependencies for `FirebaseAuth` and `FirebaseCore`.

After that, the login screen supports:

- Create account with email and password
- Sign in with email and password
- Send password reset email

## Notes

All app UI and state logic now live in Swift files under `HabitQuest/`.
