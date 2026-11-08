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
            // Not `.inspector`: on macOS 27 it loops the layout in the detail column (see `resizableInspector`).
            RequestPane()
                .resizableInspector(isPresented: store.isInspectorShown, minContentWidth: RequestPane.minWidth) {
                    RequestInspector()
                }
        }
        .navigationTitle(scopeTitle)
        .navigationSubtitle(
            store.isPaused ? pausedText(waiting: store.waitingRequestCount) : requestCountText(store.visibleRequests.count)
        )
        .searchable(text: $store.filterText)
        .toolbar {
            Button(store.isPaused ? "Resume" : "Pause", systemImage: store.isPaused ? "play.fill" : "pause.fill") {
                store.togglePause()
            }
            .help(store.isPaused ? "Resume live updates (⌘P)" : "Pause live updates (⌘P)")
            Button("Clear", systemImage: "trash") {
                store.clearRequests()
            }
            .help(store.scope == .all ? "Clear all requests" : "Clear the requests of \(scopeTitle)")
            .disabled(!store.canClear)
            HostFilterButton()
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
        guard case .app(let id) = store.scope, let client = store.client(id: id) else {
            return "All Requests"
        }
        return client.appName
    }
}
