import SwiftUI

/// The main area of the window: the listener failure bar, then the request table or an empty state.
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
                RequestTable()
            }
        }
        .frame(minWidth: 420)
    }
}
