import SwiftUI

/// The Settings window (NetworkTrail > Settings…, ⌘,).
struct SettingsView: View {
    @AppStorage(MenuBarItemSetting.key) private var showsMenuBarItem = false

    var body: some View {
        Form {
            Toggle("Show NetworkTrail in the menu bar", isOn: $showsMenuBarItem)
        }
        .padding(20)
        .frame(width: 360)
    }
}
