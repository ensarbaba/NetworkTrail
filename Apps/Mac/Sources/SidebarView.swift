import SwiftUI
import NetworkTrailWire

/// "All Requests", then one row for each app. The selection sets `SessionStore.scope`.
struct SidebarView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        let clients = store.sortedClients
        let requestCounts = store.requestCounts
        let appNameCounts = Dictionary(clients.map { ($0.appName, 1) }, uniquingKeysWith: +)
        List(selection: scopeSelection) {
            Label("All Requests", systemImage: "list.bullet")
                .badge(store.requests.count)
                .help(requestCountText(store.requests.count))
                .tag(RequestScope.all)
            if !clients.isEmpty {
                Section("Apps") {
                    ForEach(clients) { client in
                        let count = requestCounts[client.id, default: 0]
                        AppRow(client: client, showsSimulator: appNameCounts[client.appName, default: 0] > 1)
                            .badge(count)
                            .help("\(client.isConnected ? "Connected" : "Disconnected") · \(requestCountText(count))")
                            .tag(RequestScope.app(client.id))
                            .contextMenu {
                                Button("Remove App and Its Requests") {
                                    store.removeApp(client.id)
                                }
                                .disabled(client.isConnected)
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
    }

    /// `List` can set an empty selection (Command-click). The scope then stays as it is.
    private var scopeSelection: Binding<RequestScope?> {
        Binding(
            get: { store.scope },
            set: { newValue in
                if let newValue {
                    store.scope = newValue
                }
            }
        )
    }
}

/// One app in the sidebar: a green dot while connected, a gray dot after it disconnects.
/// The Simulator shows below the name only when another row has the same app name.
private struct AppRow: View {
    let client: CapturedClient
    let showsSimulator: Bool

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(client.appName)
                if showsSimulator {
                    Text("\(client.deviceName) · iOS \(client.systemVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(client.isConnected ? .green : .secondary)
                .accessibilityLabel(client.isConnected ? "Connected" : "Disconnected")
        }
        .foregroundStyle(client.isConnected ? .primary : .secondary)
    }
}
