import SwiftUI
import NetworkTrailWire

/// `SessionScreen` is the three-column Mac window: devices, request table, detail pane. Reads `SessionStore`.
///
/// Our SwiftUI, not Pulse’s console. No color-scheme override — follows the system.
struct SessionScreen: View {
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } content: {
            RequestListView()
        } detail: {
            RequestDetailView()
        }
        .navigationTitle("NetworkTrail")
    }
}

/// Listener status plus the list of phones that have connected.
private struct SidebarView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        @Bindable var store = store
        List(selection: $store.selectedClientID) {
            Section("Status") {
                Label(store.isListening ? "Listening" : "Idle", systemImage: store.isListening ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                Text(store.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = store.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Section("Setup") {
                Button("Copy iOS Simulator snippet") {
                    Pasteboard.copy(SimulatorSnippet.source)
                }
            }
            Section("Connected apps") {
                if store.clients.isEmpty {
                    Text("No app connected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.clients) { client in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(client.appName).font(.headline)
                            Text("\(client.deviceName) · iOS \(client.systemVersion)").font(.subheadline)
                            Text(client.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(client.id as String?)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let version = releaseVersionString() {
                Text(version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
    }
}

/// Filter box and the live request table (`SessionStore.filteredRequests`), or an empty state.
private struct RequestListView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            HStack {
                TextField("Filter URL, method, status", text: $store.filterText)
                    .textFieldStyle(.roundedBorder)
                Text("\(store.filteredRequests.count) requests")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            if store.clients.isEmpty {
                ContentUnavailableView(
                    "Waiting for an app",
                    systemImage: "iphone",
                    description: Text("Paste the Simulator snippet into your iOS app and run a Debug build in the Simulator. Traffic appears here live.")
                )
            } else if store.filteredRequests.isEmpty {
                ContentUnavailableView(
                    "No requests yet",
                    systemImage: "network",
                    description: Text("Trigger HTTP calls from the connected app.")
                )
            } else {
                Table(store.filteredRequests, selection: $store.selectedRequestID) {
                    TableColumn("Status") { request in
                        Text(statusLabel(for: request))
                            .fontWeight(.semibold)
                            .foregroundStyle(statusColor(for: request))
                            .monospacedDigit()
                    }
                    .width(60)
                    TableColumn("Method") { request in
                        Text(request.method)
                    }
                    .width(70)
                    TableColumn("Host") { request in
                        Text(request.host)
                            .lineLimit(1)
                    }
                    .width(min: 100, ideal: 150)
                    TableColumn("Path") { request in
                        Text(request.pathAndQuery)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(request.url)
                    }
                    TableColumn("Time") { request in
                        Text(durationLabel(for: request))
                            .monospacedDigit()
                    }
                    .width(70)
                }
                .contextMenu(forSelectionType: CapturedRequest.ID.self) { ids in
                    if ids.count == 1, let request = store.requests.first(where: { ids.contains($0.id) }) {
                        Button("Copy URL") { Pasteboard.copy(request.url) }
                        Button("Copy as cURL") { Pasteboard.copy(CurlBuilder.make(from: request)) }
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
}

/// Marketing version from `CFBundleShortVersionString`. Nil when missing or empty (`swift run` has no release plist).
func releaseVersionString(from bundle: Bundle = .main) -> String? {
    guard let raw = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
        return nil
    }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
