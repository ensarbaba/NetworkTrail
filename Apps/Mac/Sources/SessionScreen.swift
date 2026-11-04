import SwiftUI
import NetworkTrailWire

/// `SessionScreen` is the Mac window: apps in the sidebar, the request pane, and the request inspector on the right.
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
            RequestPane()
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
