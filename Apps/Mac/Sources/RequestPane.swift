import SwiftUI

/// The main area of the window: the red listener failure bar with Retry, the yellow Paused bar with Resume,
/// the health filter bar (when the scope has requests), the first-run screen (until an app connects),
/// the request table or an empty state ("No requests yet", or "No results" with Show All Requests),
/// and a bottom bar with the Setup Snippet button.
/// The bottom bar stays visible when the sidebar is hidden.
struct RequestPane: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            if let failure = store.listenerFailure {
                HStack {
                    Label("NetworkTrail can't receive requests: \(failure.reason)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Spacer()
                    // A Retry that fails again changes only this time: the new listener fails in less than 1 ms.
                    Text("Checked at \(failure.date.formatted(.dateTime.hour().minute().second()))")
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Button("Retry") {
                        store.retryListening()
                    }
                    .controlSize(.small)
                    .help("Try again to receive requests")
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(.red.opacity(0.12))
            }

            if store.isPaused {
                HStack {
                    Label {
                        Text(pausedText(waiting: store.waitingRequestCount))
                    } icon: {
                        Image(systemName: "pause.circle.fill")
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Button("Resume") {
                        store.togglePause()
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(.yellow.opacity(0.18))
            }

            if store.clients.isEmpty {
                FirstRunView()
            } else if store.scopedRequests.isEmpty {
                ContentUnavailableView("No requests yet", systemImage: "network", description: Text(noRequestsText))
                    .frame(maxHeight: .infinity)
            } else {
                HealthFilterBar()
                if !store.filteredRequests.isEmpty {
                    RequestTable()
                } else {
                    ContentUnavailableView {
                        Label(
                            noResultsTitle,
                            systemImage: searchText.isEmpty ? "line.3.horizontal.decrease.circle" : "magnifyingglass"
                        )
                    } description: {
                        Text(noResultsText)
                    } actions: {
                        Button("Show All Requests") {
                            store.clearFilters()
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }

            Divider()
            Button("Setup Snippet") {
                store.isShowingSetupSnippet = true
            }
            .controlSize(.small)
            .help("Show the snippet that adds NetworkTrail to an iOS app")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
        }
        .frame(minWidth: Self.minWidth)
    }

    /// The narrowest width of the pane. The inspector handle stops before the pane becomes narrower.
    static let minWidth: CGFloat = 420

    /// What to do to get requests: names the selected app, or the connected app when there is only one.
    private var noRequestsText: String {
        if case .app(let id) = store.scope, let client = store.client(id: id) {
            return client.isConnected
                ? "Trigger HTTP calls in \(client.appName)."
                : "\(client.appName) is not connected. Run it in the Simulator."
        }
        let connectedClients = store.clients.filter(\.isConnected)
        switch connectedClients.count {
        case 0: return "No app is connected. Run an app with the snippet in the Simulator."
        case 1: return "Trigger HTTP calls in \(connectedClients[0].appName)."
        default: return "Trigger HTTP calls in a connected app."
        }
    }

    /// The search text without spaces at the ends, as `SessionStore.filteredRequests` uses it.
    private var searchText: String {
        store.filterText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "No results for “dup”" for a search, else the title of the health filter, for example "No failed requests".
    private var noResultsTitle: String {
        searchText.isEmpty ? store.healthFilter.emptyTitle : "No results for “\(searchText)”"
    }

    /// What hides the rows, and the app: "No request of NetworkTrail Demo matches the search and the Failed filter."
    private var noResultsText: String {
        var filters: [String] = []
        if !searchText.isEmpty {
            filters.append("the search")
        }
        if store.healthFilter != .all {
            filters.append("the \(store.healthFilter.title) filter")
        }
        if store.visibleRequests.count < store.scopedRequests.count {
            filters.append("the host filter")
        }
        // English list, as the rest of the UI: "a and b", or "a, b, and c".
        let filterText = filters.count < 3
            ? filters.joined(separator: " and ")
            : filters.dropLast().joined(separator: ", ") + ", and " + filters[filters.count - 1]
        if case .app(let id) = store.scope, let client = store.client(id: id) {
            return "No request of \(client.appName) matches \(filterText)."
        }
        return "No request matches \(filterText)."
    }
}
