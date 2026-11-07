import Foundation
import NetworkTrailWire
import Observation

/// What the request table shows: every request, or the requests of one app.
enum RequestScope: Hashable {
    case all
    case app(CapturedClient.ID)
}

/// The health filter above the request table (`SessionInsights`).
enum HealthFilter: CaseIterable, Identifiable {
    case all
    case failed
    case slow
    case duplicates

    var id: Self { self }
}

/// Why the listener cannot accept connections, and when the failure came. Each failed Retry gives a new date.
struct ListenerFailure {
    let reason: String
    let date: Date
}

/// `SessionStore` holds live Mac UI state: connected apps, HTTP rows, selection, the search text, and the health filter.
///
/// Owns a `PulseListenerServer` and applies each `SessionEvent`. Only `healthLimits` is saved (in `UserDefaults`).
/// SwiftUI views update when a property that they read changes.
@Observable
@MainActor
final class SessionStore {
    /// Apps that have said hello, latest launch first.
    var clients: [CapturedClient] = []
    /// HTTP rows from every client; the list view usually shows `filteredRequests`.
    var requests: [CapturedRequest] = []
    /// The sidebar selection.
    var scope: RequestScope = .all
    var selectedRequestID: UUID?
    /// Search text from the toolbar: matches URL, method, or status code (case-insensitive URL/method).
    var filterText = ""
    /// The active health filter. Not saved: each start shows all requests.
    var healthFilter = HealthFilter.all
    /// True while the table is paused: request updates wait in `pausedUpdates` until Resume.
    /// Not saved: each start is live.
    private(set) var isPaused = false
    /// Request updates that arrived while paused, in arrival order. A newer update of a request
    /// replaces the older one in its place.
    private var pausedUpdates: [CapturedRequest] = []
    /// The limits of the Slow and Duplicate rules. Saved on each change.
    var healthLimits = HealthLimits.saved {
        didSet { healthLimits.save() }
    }
    /// Why the listener cannot accept connections, and when. Nil while it works.
    var listenerFailure: ListenerFailure?
    /// True while the Setup Snippet sheet shows. The button in the bottom bar and the File menu set it.
    var isShowingSetupSnippet = false
    /// True while the request inspector shows. The toolbar button and the View menu toggle it;
    /// a double-click or Return on a table row opens it.
    var isInspectorShown = false

    private var server: PulseListenerServer?

    /// Start the listener. Second call does nothing while one is already running.
    func startListening() {
        guard server == nil else { return }
        let server = PulseListenerServer { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }
        self.server = server
        server.start()
    }

    /// Replace the failed listener with a new one, for example after the app that held the port quit.
    func retryListening() {
        server?.restart()
    }

    /// Apply one `SessionEvent` from the listener: ready/fail, device join/leave, or insert/replace a request.
    private func handle(_ event: SessionEvent) {
        switch event {
        case .listenerReady:
            listenerFailure = nil
        case .listenerFailed(let message):
            listenerFailure = ListenerFailure(reason: message, date: .now)
        case .clientConnected(let client):
            clients.removeAll { $0.id == client.id }
            clients.insert(client, at: 0)
        case .clientDisconnected(let id):
            if let index = clients.firstIndex(where: { $0.id == id }) {
                clients[index].isConnected = false
            }
        case .requestUpdated(let request):
            if isPaused {
                if let index = pausedUpdates.firstIndex(where: { $0.id == request.id }) {
                    pausedUpdates[index] = request
                } else {
                    pausedUpdates.append(request)
                }
            } else {
                apply(request)
            }
        }
    }

    /// Insert a new row on top, or replace the row with the same ID.
    private func apply(_ request: CapturedRequest) {
        if let index = requests.firstIndex(where: { $0.id == request.id }) {
            requests[index] = request
        } else {
            requests.insert(request, at: 0)
        }
        if selectedRequestID == nil {
            selectedRequestID = request.id
        }
    }

    /// Pause: the table, its counts, and running rows stop changing. Resume: the waiting updates apply in order.
    func togglePause() {
        if isPaused {
            pausedUpdates.forEach(apply)
            pausedUpdates.removeAll()
        }
        isPaused.toggle()
    }

    /// Number of new requests in `scope` that wait for Resume. Updates of rows in the table do not count.
    var waitingRequestCount: Int {
        let shownIDs = Set(requests.map(\.id))
        return pausedUpdates.filter { !shownIDs.contains($0.id) && isInScope($0) }.count
    }

    /// Remove a disconnected app and its requests. If the sidebar showed that app, it shows all requests.
    /// Not for a connected app: its next requests would have no row in the sidebar.
    func removeApp(_ id: CapturedClient.ID) {
        if selectedRequest?.clientID == id {
            selectedRequestID = nil
        }
        clients.removeAll { $0.id == id }
        requests.removeAll { $0.clientID == id }
        pausedUpdates.removeAll { $0.clientID == id }
        if scope == .app(id) {
            scope = .all
        }
    }

    /// The app with this ID, if it is in the session.
    func client(id: CapturedClient.ID) -> CapturedClient? {
        clients.first { $0.id == id }
    }

    /// Apps in sidebar order: connected apps first, then disconnected apps. Each group keeps latest launch first.
    var sortedClients: [CapturedClient] {
        clients.filter(\.isConnected) + clients.filter { !$0.isConnected }
    }

    /// Show every request of the selected app: clear the search text and the health filter. The app stays selected.
    func clearFilters() {
        filterText = ""
        healthFilter = .all
    }

    /// Number of requests of each app.
    var requestCounts: [CapturedClient.ID: Int] {
        requests.reduce(into: [:]) { counts, request in
            counts[request.clientID, default: 0] += 1
        }
    }

    /// Remove the requests in `scope`, and the updates of `scope` that wait for Resume. The app rows stay.
    func clearRequests() {
        requests.removeAll(where: isInScope)
        pausedUpdates.removeAll(where: isInScope)
        if selectedRequest == nil {
            selectedRequestID = nil
        }
    }

    /// True when Clear has something to remove: rows in `scope`, or new requests that wait for Resume.
    var canClear: Bool {
        !scopedRequests.isEmpty || waitingRequestCount > 0
    }

    /// Rows in `scope`, before `filterText`.
    var scopedRequests: [CapturedRequest] {
        requests.filter(isInScope)
    }

    private func isInScope(_ request: CapturedRequest) -> Bool {
        guard case .app(let id) = scope else { return true }
        return request.clientID == id
    }

    /// Failed, slow, and duplicate requests in `scope`, before `filterText`.
    var insights: SessionInsights {
        SessionInsights(requests: scopedRequests, limits: healthLimits)
    }

    /// `scopedRequests` narrowed by `healthFilter` and `filterText`.
    var filteredRequests: [CapturedRequest] {
        var requests = scopedRequests
        if healthFilter != .all {
            let insights = self.insights
            requests = requests.filter { request in
                switch healthFilter {
                case .all: true
                case .failed: insights.failed.contains(request.id)
                case .slow: insights.slow.contains(request.id)
                case .duplicates: insights.duplicates[request.id] != nil
                }
            }
        }
        let trimmed = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return requests }
        return requests.filter {
            $0.url.localizedCaseInsensitiveContains(trimmed)
                || $0.method.localizedCaseInsensitiveContains(trimmed)
                || ($0.statusCode.map(String.init) ?? "").contains(trimmed)
        }
    }

    /// The request that the inspector shows, if any.
    var selectedRequest: CapturedRequest? {
        guard let selectedRequestID else { return nil }
        return requests.first { $0.id == selectedRequestID }
    }
}
