import SwiftUI

@main
struct HabitQuestApp: App {
    @StateObject private var store: HabitQuestStore

    init() {
        FirebaseBootstrap.configureIfPossible()
        _store = StateObject(wrappedValue: HabitQuestStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}
