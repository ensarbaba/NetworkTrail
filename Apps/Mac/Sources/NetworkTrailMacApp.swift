import AppKit
import SwiftUI

/// Mac app entry: one window, one `SessionStore`, `SessionScreen` as the root view.
/// Also the Settings window and the optional menu bar item.
///
/// `AppDelegate` owns the store and starts the listener at launch. Follows the system appearance.
@main
struct NetworkTrailMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(MenuBarItemSetting.key) private var showsMenuBarItem = false

    private var store: SessionStore {
        appDelegate.store
    }

    var body: some Scene {
        WindowGroup(id: MainWindow.id) {
            SessionScreen()
                .environment(store)
                .onAppear { appDelegate.requestWindowDidAppear() }
        }
        // Reads the setting only: no write back (see `menuBarItemInserted`).
        .onChange(of: showsMenuBarItem) { _, isShown in
            appDelegate.menuBarItemSettingDidChange(isShown: isShown)
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

        Settings {
            SettingsView()
        }

        MenuBarExtra(isInserted: menuBarItemInserted) {
            MenuBarMenu()
                .environment(store)
        } label: {
            // Without this label, VoiceOver reads the asset name.
            Image("MenuBarIcon")
                .accessibilityLabel("NetworkTrail")
        }
    }

    /// The setting, for `MenuBarExtra`. A removal from the menu bar (Command-drag) sets it to false.
    ///
    /// Writes only a changed value: `MenuBarExtra` writes the same value back on each scene update, and
    /// each `@AppStorage` write updates the App scene again. With `$showsMenuBarItem` the app loops at 100 % CPU.
    private var menuBarItemInserted: Binding<Bool> {
        Binding(
            get: { showsMenuBarItem },
            set: { newValue in
                if newValue != showsMenuBarItem {
                    showsMenuBarItem = newValue
                }
            }
        )
    }

    /// Put the cursor in the toolbar search field. macOS 14 has no SwiftUI call for this
    /// (`searchFocused` needs macOS 15). SwiftUI shows `.searchable` as an `NSSearchToolbarItem`.
    private static func focusSearchField() {
        let searchItem = NSApp.keyWindow?.toolbar?.items.lazy.compactMap { $0 as? NSSearchToolbarItem }.first
        searchItem?.beginSearchInteraction()
    }
}
