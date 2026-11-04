import SwiftUI
import NetworkTrailWire

/// `SessionScreen` is the Mac window: apps in the sidebar, the request table, and the request inspector on the right.
/// Reads `SessionStore`.
///
/// Our SwiftUI, not Pulse’s console. No color-scheme override — follows the system.
struct SessionScreen: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            SidebarView()
        } detail: {
            RequestListView()
                .inspector(isPresented: $store.isInspectorShown) {
                    RequestDetailView()
                        .inspectorColumnWidth(min: 320, ideal: 420, max: 720)
                }
        }
        .navigationTitle(scopeTitle)
        .navigationSubtitle(requestCountText(store.scopedRequests.count))
        .searchable(text: $store.filterText)
        .toolbar {
            Button("Clear", systemImage: "trash") {
                store.clearRequests()
            }
            .help(store.scope == .all ? "Clear all requests" : "Clear the requests of \(scopeTitle)")
            .disabled(store.scopedRequests.isEmpty)
            Button(store.isInspectorShown ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.trailing") {
                store.isInspectorShown.toggle()
            }
            .help(store.isInspectorShown ? "Hide the request details" : "Show the request details")
        }
        .sheet(isPresented: $store.isShowingSetupSnippet) {
            SetupSnippetView()
        }
    }

    /// "All Requests", or the name of the app that the sidebar selects.
    private var scopeTitle: String {
        guard case .app(let id) = store.scope, let client = store.clients.first(where: { $0.id == id }) else {
            return "All Requests"
        }
        return client.appName
    }
}

/// "All Requests", then one row for each app. The selection sets `SessionStore.scope`.
/// The Setup Snippet button stays at the bottom, below the list.
private struct SidebarView: View {
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                store.isShowingSetupSnippet = true
            } label: {
                Label("Setup Snippet", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Show the snippet that adds NetworkTrail to an iOS app")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
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

/// "1 request" or "N requests".
private func requestCountText(_ count: Int) -> String {
    count == 1 ? "1 request" : "\(count) requests"
}

/// Listener failure bar and the live request table (`SessionStore.filteredRequests`), or an empty state.
private struct RequestListView: View {
    @Environment(SessionStore.self) private var store
    /// Column choices: one set while the inspector is hidden, one while it shows. JSON in `UserDefaults`,
    /// because `@SceneStorage` is lost when macOS closes the windows on quit.
    @AppStorage("requestTable.columns.wide") private var wideColumns = Data()
    @AppStorage("requestTable.columns.narrow") private var narrowColumns = Data()

    var body: some View {
        @Bindable var store = store
        // While the inspector shows, Start, Host, and Size are hidden unless the user shows them.
        let narrowSetVisibility: Visibility = store.isInspectorShown ? .hidden : .automatic
        VStack(spacing: 0) {
            if let listenerError = store.listenerError {
                Label("NetworkTrail can't receive requests: \(listenerError)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.12))
            }

            if store.clients.isEmpty {
                ContentUnavailableView(
                    "Waiting for an app",
                    systemImage: "iphone",
                    description: Text("Paste the Simulator snippet into your iOS app and run a Debug build in the Simulator. Traffic appears here live.")
                )
                .frame(maxHeight: .infinity)
            } else if store.scopedRequests.isEmpty {
                ContentUnavailableView(
                    "No requests yet",
                    systemImage: "network",
                    description: Text("Trigger HTTP calls from the connected app.")
                )
                .frame(maxHeight: .infinity)
            } else if store.filteredRequests.isEmpty {
                ContentUnavailableView.search(text: store.filterText)
                    .frame(maxHeight: .infinity)
            } else {
                Table(
                    store.filteredRequests,
                    selection: $store.selectedRequestID,
                    columnCustomization: columnCustomization
                ) {
                    TableColumn("Start") { request in
                        Text(request.createdAt, format: .dateTime.hour().minute().second())
                            .monospacedDigit()
                    }
                    .width(min: 60, ideal: 80, max: 110)
                    .customizationID("start")
                    .defaultVisibility(narrowSetVisibility)
                    TableColumn("Status") { request in
                        Text(statusLabel(for: request))
                            .fontWeight(.semibold)
                            .foregroundStyle(statusColor(for: request))
                            .monospacedDigit()
                    }
                    .width(60)
                    .customizationID("status")
                    .disabledCustomizationBehavior(.visibility)
                    TableColumn("Method") { request in
                        Text(request.method)
                    }
                    .width(70)
                    .customizationID("method")
                    TableColumn("Host") { request in
                        Text(request.host)
                            .lineLimit(1)
                    }
                    .width(min: 100, ideal: 150, max: 260)
                    .customizationID("host")
                    .defaultVisibility(narrowSetVisibility)
                    TableColumn("Path") { request in
                        Text(request.pathAndQuery)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(request.url)
                    }
                    .customizationID("path")
                    .disabledCustomizationBehavior(.visibility)
                    TableColumn("Size") { request in
                        Text(sizeLabel(for: request))
                            .monospacedDigit()
                    }
                    .width(70)
                    .customizationID("size")
                    .defaultVisibility(narrowSetVisibility)
                    TableColumn("Duration") { request in
                        Text(durationLabel(for: request))
                            .monospacedDigit()
                    }
                    .width(70)
                    .customizationID("duration")
                }
                .contextMenu(forSelectionType: CapturedRequest.ID.self) { ids in
                    if ids.count == 1, let request = store.requests.first(where: { ids.contains($0.id) }) {
                        Button("Copy URL") { Pasteboard.copy(request.url) }
                        Button("Copy as cURL") { Pasteboard.copy(CurlBuilder.make(from: request)) }
                    }
                } primaryAction: { ids in
                    // Double-click or Return on a row.
                    if !ids.isEmpty {
                        store.isInspectorShown = true
                    }
                }
            }
        }
        .frame(minWidth: 420)
    }

    /// Status code, "Failed" for a call that ended with an error and no response, "—" if finished with no code,
    /// or an ellipsis while in flight.
    private func statusLabel(for request: CapturedRequest) -> String {
        if let code = request.statusCode { return String(code) }
        if request.errorDescription != nil { return "Failed" }
        return request.isComplete ? "—" : "…"
    }

    /// Red for errors and 5xx, orange for 4xx, green for 2xx; secondary for 3xx, unknown, and in flight.
    private func statusColor(for request: CapturedRequest) -> Color {
        if request.errorDescription != nil { return .red }
        switch request.statusCode {
        case .some(200..<300): return .green
        case .some(400..<500): return .orange
        case .some(500...): return .red
        default: return .secondary
        }
    }

    /// Milliseconds below one second (`556 ms`), seconds from one second (`1.1 s`), or an em dash if unknown.
    private func durationLabel(for request: CapturedRequest) -> String {
        guard let duration = request.duration else { return "—" }
        return duration < 1
            ? String(format: "%.0f ms", duration * 1000)
            : String(format: "%.1f s", duration)
    }

    /// Response body size, for example `2 kB` or `380 bytes`, or an em dash while in flight or without a body.
    private func sizeLabel(for request: CapturedRequest) -> String {
        guard let body = request.responseBody else { return "—" }
        return Int64(body.count).formatted(.byteCount(style: .file, spellsOutZero: false))
    }

    /// The column choices of the current inspector state, read from and written to `@AppStorage`.
    private var columnCustomization: Binding<TableColumnCustomization<CapturedRequest>> {
        let storage = store.isInspectorShown ? $narrowColumns : $wideColumns
        return Binding(
            get: { (try? JSONDecoder().decode(TableColumnCustomization<CapturedRequest>.self, from: storage.wrappedValue)) ?? TableColumnCustomization() },
            set: { storage.wrappedValue = (try? JSONEncoder().encode($0)) ?? Data() }
        )
    }
}
