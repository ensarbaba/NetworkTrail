import AppKit

/// Owns the `SessionStore` and starts the listener at launch, so that NetworkTrail receives traffic
/// also when no window opens (a start at login).
///
/// Decides when NetworkTrail runs in the menu bar only: while the menu bar item shows and no request
/// window is open, NetworkTrail has no Dock icon. The Dock icon comes back when the window opens.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = SessionStore()
    /// True for the first seconds after a start at login with the menu bar item on: a request window that
    /// macOS restores then closes, so that NetworkTrail starts in the menu bar only.
    private var closesRestoredWindows = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.startListening()
        // The open event is available here, not yet in `applicationWillFinishLaunching`.
        if Self.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent), MenuBarItemSetting.isShown {
            // At a login start AppKit opens no new window by itself, so the Dock icon hides at once.
            NSApp.setActivationPolicy(.accessory)
            closesRestoredWindows = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                closesRestoredWindows = false
            }
        }
        // Any closed window: the check looks at the request window itself, so other windows change nothing.
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // After the close: until then, the window still counts as open.
            Task { @MainActor in
                self?.updateActivationPolicy()
            }
        }
    }

    /// Called when a request window appears. Closes a window that macOS restores at a login start.
    /// A window that the user opens stays: `MainWindow.show(using:)` sets the Dock icon before it opens one.
    func requestWindowDidAppear() {
        guard closesRestoredWindows, NSApp.activationPolicy() == .accessory else {
            updateActivationPolicy()
            return
        }
        // After SwiftUI has shown the window, so that the close is not lost.
        Task { @MainActor in
            MainWindow.openRequestWindow?.close()
        }
    }

    /// The setting "Show NetworkTrail in the menu bar" changed. Without the menu bar item, NetworkTrail
    /// does not open at login (that setting works only with the item), and it keeps its Dock icon.
    func menuBarItemSettingDidChange(isShown: Bool) {
        if !isShown {
            LoginItem.unregister()
        }
        updateActivationPolicy()
    }

    /// No Dock icon while the menu bar item shows and no request window is open.
    /// With the menu bar item off, the Dock icon always shows: else nothing could open NetworkTrail.
    func updateActivationPolicy() {
        let runsInMenuBarOnly = MenuBarItemSetting.isShown && MainWindow.openRequestWindow == nil
        let policy: NSApplication.ActivationPolicy = runsInMenuBarOnly ? .accessory : .regular
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
        }
    }

    /// True when `event` is the open event of a login item start (`keyAELaunchedAsLogInItem`).
    nonisolated static func isLoginLaunch(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventID == AEEventID(kAEOpenApplication) else { return false }
        return event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
    }
}
