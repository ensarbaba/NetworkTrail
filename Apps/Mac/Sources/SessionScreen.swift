import SwiftUI
import NetworkTrailWire

/// `SessionScreen` is the three-column Mac window: devices, request table, detail pane. Reads `SessionStore`.
///
/// Our SwiftUI on macOS 13, not Pulse’s console. No color-scheme override — follows the system.
struct SessionScreen: View {
    @EnvironmentObject private var store: SessionStore

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
    @EnvironmentObject private var store: SessionStore

    var body: some View {
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
            Section("Devices") {
                if store.clients.isEmpty {
                    Text("No device connected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.clients) { client in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(client.deviceName).font(.headline)
                            Text(client.appName).font(.subheadline)
                            Text(client.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(client.id as UUID?)
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
    @EnvironmentObject private var store: SessionStore

    var body: some View {
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
                EmptyStateView(
                    title: "Waiting for a device",
                    message: "Run the demo iOS app in the Simulator with the Debug SDK enabled. Traffic appears here live."
                )
            } else if store.filteredRequests.isEmpty {
                EmptyStateView(
                    title: "No requests yet",
                    message: "Trigger HTTP calls from the connected app."
                )
            } else {
                Table(store.filteredRequests, selection: $store.selectedRequestID) {
                    TableColumn("Method") { request in
                        Text(request.method)
                            .fontWeight(.semibold)
                    }
                    .width(70)
                    TableColumn("Status") { request in
                        Text(statusLabel(for: request))
                    }
                    .width(60)
                    TableColumn("URL") { request in
                        Text(request.url)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    TableColumn("Time") { request in
                        Text(durationLabel(for: request))
                            .monospacedDigit()
                    }
                    .width(70)
                }
            }
        }
        .frame(minWidth: 420)
    }

    /// Status code, an em dash if finished with no code, or an ellipsis while in flight.
    private func statusLabel(for request: CapturedRequest) -> String {
        if let code = request.statusCode { return String(code) }
        return request.isComplete ? "—" : "…"
    }

    /// Total duration in milliseconds, or an em dash if unknown.
    private func durationLabel(for request: CapturedRequest) -> String {
        guard let duration = request.duration else { return "—" }
        return String(format: "%.0f ms", duration * 1000)
    }
}

/// Centered title + message used when there is no device or no matching rows.
struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.title3)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
