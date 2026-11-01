import Foundation
import NetworkTrailWire
import Observation

/// What the request table shows: every request, or the requests of one app.
enum RequestScope: Hashable {
    case all
    case app(CapturedClient.ID)
}

/// `SessionStore` holds live Mac UI state: connected apps, HTTP rows, selection, and the filter box.
///
/// Owns a `PulseListenerServer` and applies each `SessionEvent`. Nothing is saved to disk.
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
    /// Filter box: matches URL, method, or status code (case-insensitive URL/method).
    var filterText = ""
    /// Why the listener cannot accept connections. Nil while it works.
    var listenerError: String?

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

    /// Apply one `SessionEvent` from the listener: ready/fail, device join/leave, or insert/replace a request.
    private func handle(_ event: SessionEvent) {
        switch event {
        case .listenerReady:
            listenerError = nil
        case .listenerFailed(let message):
            listenerError = message
        case .clientConnected(let client):
            clients.removeAll { $0.id == client.id }
            clients.insert(client, at: 0)
        case .clientDisconnected(let id):
            if let index = clients.firstIndex(where: { $0.id == id }) {
                clients[index].isConnected = false
            }
        case .requestUpdated(let request):
            if let index = requests.firstIndex(where: { $0.id == request.id }) {
                requests[index] = request
            } else {
                requests.insert(request, at: 0)
            }
            if selectedRequestID == nil {
                selectedRequestID = request.id
            }
        }
    }

    /// Remove a disconnected app and its requests. If the sidebar showed that app, it shows all requests.
    /// Not for a connected app: its next requests would have no row in the sidebar.
    func removeApp(_ id: CapturedClient.ID) {
        if selectedRequest?.clientID == id {
            selectedRequestID = nil
        }
        clients.removeAll { $0.id == id }
        requests.removeAll { $0.clientID == id }
        if scope == .app(id) {
            scope = .all
        }
    }

    /// Apps in sidebar order: connected apps first, then disconnected apps. Each group keeps latest launch first.
    var sortedClients: [CapturedClient] {
        clients.filter(\.isConnected) + clients.filter { !$0.isConnected }
    }

    /// Number of requests of each app.
    var requestCounts: [CapturedClient.ID: Int] {
        requests.reduce(into: [:]) { counts, request in
            counts[request.clientID, default: 0] += 1
        }
    }

    /// Rows in `scope`, then narrowed by `filterText`.
    var filteredRequests: [CapturedRequest] {
        let scoped = requests.filter { request in
            guard case .app(let id) = scope else { return true }
            return request.clientID == id
        }
        let trimmed = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return scoped }
        return scoped.filter {
            $0.url.localizedCaseInsensitiveContains(trimmed)
                || $0.method.localizedCaseInsensitiveContains(trimmed)
                || ($0.statusCode.map(String.init) ?? "").contains(trimmed)
        }
    }

    /// The request the detail pane should show, if any.
    var selectedRequest: CapturedRequest? {
        guard let selectedRequestID else { return nil }
        return requests.first { $0.id == selectedRequestID }
    }
}
