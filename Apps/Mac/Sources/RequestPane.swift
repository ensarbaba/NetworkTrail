import SwiftUI

/// The main area of the window: the listener failure bar, the yellow Paused bar with Resume,
/// the health filter bar (when the scope has requests),
/// the request table or an empty state, and a bottom bar with the Setup Snippet button.
/// The bottom bar stays visible when the sidebar is hidden.
struct RequestPane: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            if let listenerError = store.listenerError {
                Label("NetworkTrail can't receive requests: \(listenerError)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
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
            } else {
                HealthFilterBar()
                if !store.filteredRequests.isEmpty {
                    RequestTable()
                } else if store.filterText.isEmpty {
                    ContentUnavailableView(store.healthFilter.emptyTitle, systemImage: "checkmark.circle")
                        .frame(maxHeight: .infinity)
                } else {
                    ContentUnavailableView.search(text: store.filterText)
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
        .frame(minWidth: 420)
    }
}
