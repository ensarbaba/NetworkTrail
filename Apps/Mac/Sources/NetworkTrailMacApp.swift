import SwiftUI

/// Mac app entry: one window, one `SessionStore`, `SessionScreen` as the root view.
///
/// Starts the Bonjour Pulse listener when the window appears. Follows the system appearance (macOS 13).
@main
struct NetworkTrailMacApp: App {
    @StateObject private var store = SessionStore()

    var body: some Scene {
        WindowGroup {
            SessionScreen()
                .environmentObject(store)
                .onAppear { store.startListening() }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
