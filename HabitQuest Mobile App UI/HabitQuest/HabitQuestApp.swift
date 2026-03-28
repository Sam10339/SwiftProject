import SwiftUI

@main
struct HabitQuestApp: App {
    @StateObject private var store = HabitQuestStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}
