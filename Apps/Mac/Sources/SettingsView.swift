import ServiceManagement
import SwiftUI

/// The Settings window (NetworkTrail > Settings…, ⌘,).
struct SettingsView: View {
    @AppStorage(MenuBarItemSetting.key) private var showsMenuBarItem = false
    /// Read from macOS each time, not saved: the user can remove the login item in System Settings.
    @State private var loginItemStatus = LoginItem.status
    @State private var loginItemError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Show NetworkTrail in the menu bar", isOn: $showsMenuBarItem)
            // Under the menu bar item, because it works only with it: at login NetworkTrail has no window.
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Open at login, in the menu bar only", isOn: opensAtLogin)
                    .disabled(!showsMenuBarItem)
                Text("Starts when you log in, with no window. Click the menu bar icon to open it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 20)
                if loginItemStatus == .requiresApproval {
                    HStack {
                        Text("Allow NetworkTrail in System Settings > General > Login Items.")
                            .font(.callout)
                        Button("Open Login Items") {
                            SMAppService.openSystemSettingsLoginItems()
                        }
                        .controlSize(.small)
                    }
                    .padding(.leading, 20)
                }
                if let loginItemError {
                    Text(loginItemError)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 20)
                }
            }
            .padding(.leading, 20)
        }
        .padding(20)
        .frame(width: 420, alignment: .leading)
        .onAppear(perform: refreshLoginItemStatus)
        // The user can change the login item in System Settings while this window is open.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            refreshLoginItemStatus()
        }
        .onChange(of: showsMenuBarItem) {
            // `AppDelegate` removes the login item when the menu bar item goes off; read the result after that.
            Task { @MainActor in
                refreshLoginItemStatus()
            }
        }
    }

    /// On while macOS has the login item, also while it waits for approval in System Settings.
    private var opensAtLogin: Binding<Bool> {
        Binding(
            get: { loginItemStatus == .enabled || loginItemStatus == .requiresApproval },
            set: { isOn in
                do {
                    try LoginItem.set(isOn)
                    loginItemError = nil
                } catch {
                    loginItemError = "macOS did not change the login item: \(error.localizedDescription)"
                }
                refreshLoginItemStatus()
            }
        )
    }

    private func refreshLoginItemStatus() {
        loginItemStatus = LoginItem.status
    }
}

/// NetworkTrail as a login item (`SMAppService.mainApp`). macOS lists it in System Settings > General > Login Items.
enum LoginItem {
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static func set(_ isOn: Bool) throws {
        if isOn {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Removes the login item if macOS has it. An error leaves it as it is; the Settings window shows the state.
    static func unregister() {
        guard status == .enabled || status == .requiresApproval else { return }
        try? SMAppService.mainApp.unregister()
    }
}
