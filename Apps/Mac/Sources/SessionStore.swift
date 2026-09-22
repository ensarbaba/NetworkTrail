import Foundation
import NetworkTrailWire

/// `SessionStore` holds live Mac UI state: connected phones, HTTP rows, selection, and the filter box.
///
/// Owns a `PulseListenerServer` and applies each `SessionEvent`. Nothing is saved to disk.
/// `ObservableObject` so SwiftUI on macOS 13 can observe `@Published` fields.
@MainActor
final class SessionStore: ObservableObject {
    /// Phones that have said hello (newest first).
    @Published var clients: [CapturedClient] = []
    /// HTTP rows from every client; the list view usually shows `filteredRequests`.
    @Published var requests: [CapturedRequest] = []
    @Published var selectedClientID: UUID?
    @Published var selectedRequestID: UUID?
    /// Filter box: matches URL, method, or status code (case-insensitive URL/method).
    @Published var filterText = ""
    @Published var isListening = false
    @Published var statusMessage = "Starting listener…"
    @Published var lastError: String?

    private var server: PulseListenerServer?

    /// Start the Bonjour Pulse listener. Second call does nothing while one is already running.
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

    /// Stop Bonjour and mark the store idle. Arrays are left as they are.
    func stopListening() {
        server?.stop()
        server = nil
        isListening = false
        statusMessage = "Stopped"
    }

    /// Apply one `SessionEvent` from the listener: ready/fail, device join/leave, or insert/replace a request.
    private func handle(_ event: SessionEvent) {
        switch event {
        case .listenerReady:
            isListening = true
            statusMessage = "Listening for devices on Bonjour (_pulse._tcp)"
            lastError = nil
        case .listenerFailed(let message):
            isListening = false
            lastError = message
            statusMessage = "Listener failed"
        case .clientConnected(let client):
            clients.removeAll { $0.id == client.id }
            clients.insert(client, at: 0)
            if selectedClientID == nil {
                selectedClientID = client.id
            }
        case .clientDisconnected(let id):
            clients.removeAll { $0.id == id }
            if selectedClientID == id {
                selectedClientID = clients.first?.id
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

    /// Rows for the selected device (or all devices), then narrowed by `filterText`.
    var filteredRequests: [CapturedRequest] {
        let scoped = requests.filter { request in
            guard let selectedClientID else { return true }
            return request.clientID == selectedClientID
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
