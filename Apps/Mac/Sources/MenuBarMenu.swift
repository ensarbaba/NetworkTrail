import AppKit
import SwiftUI
import NetworkTrailWire

/// The setting in the Settings window that shows the menu bar item. Off by default: the user decides.
enum MenuBarItemSetting {
    static let key = "menuBar.showsItem"

    /// The saved value, for code outside SwiftUI views.
    static var isShown: Bool {
        UserDefaults.standard.bool(forKey: key)
    }
}

/// The menu of the menu bar item: the apps with their request counts, then the window commands.
///
/// The icon shows no state, and the menu has no status lines: Paused and a listener failure show only in
/// the window. Only the Pause item changes its title, as in the View menu.
struct MenuBarMenu: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let clients = store.sortedClients
        // Without the requests to hidden hosts, the same as the sidebar.
        let requestCounts = store.requestCounts
        let appNameCounts = Dictionary(clients.map { ($0.appName, 1) }, uniquingKeysWith: +)
        if !clients.isEmpty {
            Section("Apps") {
                ForEach(clients) { client in
                    Button {
                        store.scope = .app(client.id)
                        MainWindow.show(using: openWindow)
                    } label: {
                        Label {
                            // The Simulator only when another app has the same name, as in the sidebar.
                            Text(appNameCounts[client.appName, default: 0] > 1 ? "\(client.appName) · \(client.deviceName)" : client.appName)
                        } icon: {
                            Image(nsImage: Self.connectionDot(isConnected: client.isConnected))
                        }
                        // Menus show only the title of a label by default.
                        .labelStyle(.titleAndIcon)
                    }
                    .badge(requestCounts[client.id, default: 0])
                }
            }
            Divider()
        }
        Button("Open NetworkTrail") {
            MainWindow.show(using: openWindow)
        }
        Button(store.isPaused ? "Resume Live Updates" : "Pause Live Updates") {
            store.togglePause()
        }
        // The window may be closed, so the title names what Clear removes.
        Button(clearTitle) {
            store.clearRequests()
        }
        .disabled(!store.canClear)
        Divider()
        Button("Show Setup Snippet…") {
            MainWindow.show(using: openWindow)
            store.isShowingSetupSnippet = true
        }
        Button("Quit NetworkTrail") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var clearTitle: String {
        guard case .app(let id) = store.scope, let client = store.client(id: id) else {
            return "Clear All Requests"
        }
        return "Clear Requests of \(client.appName)"
    }

    /// A green dot while the app is connected, a gray dot after it disconnects. Not a template image,
    /// so that the menu keeps the color.
    private static func connectionDot(isConnected: Bool) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 8, weight: .regular)
            .applying(.init(paletteColors: [isConnected ? .systemGreen : .secondaryLabelColor]))
        let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: isConnected ? "Connected" : "Disconnected")?
            .withSymbolConfiguration(configuration) ?? NSImage()
        image.isTemplate = false
        return image
    }
}

/// The request window. `WindowGroup(id:)` gives its `NSWindow` an identifier that starts with `id`.
enum MainWindow {
    static let id = "main"

    /// Bring the request window to the front. Opens a new window only when the user closed it,
    /// so that the menu never makes a second window.
    @MainActor
    static func show(using openWindow: OpenWindowAction) {
        // The Dock icon comes back with the window (`AppDelegate.updateActivationPolicy()`).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        guard let window = openRequestWindow else {
            openWindow(id: id)
            return
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
    }

    /// The request window when it is on screen or in the Dock. Nil after the user closed it.
    @MainActor
    static var openRequestWindow: NSWindow? {
        NSApp.windows.first { window in
            isRequestWindow(window) && (window.isVisible || window.isMiniaturized)
        }
    }

    /// True for a window of the `WindowGroup`, not for the Settings window or the menu bar menu.
    @MainActor
    static func isRequestWindow(_ window: NSWindow) -> Bool {
        window.identifier?.rawValue.hasPrefix(id) == true
    }
}
