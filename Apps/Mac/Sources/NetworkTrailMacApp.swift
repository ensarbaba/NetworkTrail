import AppKit
import SwiftUI

/// Mac app entry: one window, one `SessionStore`, `SessionScreen` as the root view.
///
/// Starts the listener when the window appears. Follows the system appearance.
@main
struct NetworkTrailMacApp: App {
    @State private var store = SessionStore()

    var body: some Scene {
        WindowGroup {
            SessionScreen()
                .environment(store)
                .onAppear { store.startListening() }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Show Setup Snippet…") {
                    store.isShowingSetupSnippet = true
                }
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Clear Requests") {
                    store.clearRequests()
                }
                .keyboardShortcut("k")
                .disabled(!store.canClear)
            }
            CommandGroup(after: .sidebar) {
                Button(store.isPaused ? "Resume Live Updates" : "Pause Live Updates") {
                    store.togglePause()
                }
                .keyboardShortcut("p")
                Button(store.isInspectorShown ? "Hide Inspector" : "Show Inspector") {
                    store.isInspectorShown.toggle()
                }
                .keyboardShortcut("0", modifiers: [.command, .option])
            }
            CommandGroup(after: .textEditing) {
                Button("Find…") {
                    Self.focusSearchField()
                }
                .keyboardShortcut("f")
            }
        }
    }

    /// Put the cursor in the toolbar search field. macOS 14 has no SwiftUI call for this
    /// (`searchFocused` needs macOS 15). SwiftUI shows `.searchable` as an `NSSearchToolbarItem`.
    private static func focusSearchField() {
        let searchItem = NSApp.keyWindow?.toolbar?.items.lazy.compactMap { $0 as? NSSearchToolbarItem }.first
        searchItem?.beginSearchInteraction()
    }
}
