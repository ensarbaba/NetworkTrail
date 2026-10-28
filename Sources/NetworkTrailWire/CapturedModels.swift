import Foundation

/// A phone or Simulator that connected to the Mac inspector.
public struct CapturedClient: Identifiable, Hashable, Sendable {
    /// The app's ID from its hello: `<bundle ID>|<Simulator ID>`, the same in every launch.
    public let id: String
    public var deviceName: String
    public var appName: String
    public var bundleIdentifier: String
    public var systemVersion: String
    public var connectedAt: Date
    /// False after the app disconnects. The app and its requests stay in the session until it connects again.
    public var isConnected: Bool

    /// Creates a client record when a device connects.
    public init(
        id: String,
        deviceName: String,
        appName: String,
        bundleIdentifier: String,
        systemVersion: String,
        connectedAt: Date = Date(),
        isConnected: Bool = true
    ) {
        self.id = id
        self.deviceName = deviceName
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.systemVersion = systemVersion
        self.connectedAt = connectedAt
        self.isConnected = isConnected
    }
}

/// One HTTP call as the Mac list shows it: method, URL, headers, bodies, and status when they exist.
///
/// Status, duration, and bodies are optional because the row can appear before the call finishes.
public struct CapturedRequest: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var clientID: String
    public var createdAt: Date
    public var method: String
    public var url: String
    public var statusCode: Int?
    public var duration: TimeInterval?
    public var requestHeaders: [String: String]
    public var responseHeaders: [String: String]
    public var requestBody: Data?
    public var responseBody: Data?
    public var errorDescription: String?
    public var isComplete: Bool

    /// Host part of `url`, or the full URL if it is not a valid URL.
    public var host: String {
        URL(string: url)?.host ?? url
    }

    /// Path and query of `url` as sent, for example `/get?probe=1`, or the full text if it has no host.
    public var pathAndQuery: String {
        guard let components = URLComponents(string: url), components.host != nil else { return url }
        let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        guard let query = components.percentEncodedQuery else { return path }
        return path + "?" + query
    }
}

/// News from the listener for `SessionStore`: apps, requests, or listener health.
public enum SessionEvent: Sendable {
    /// A device connected.
    case clientConnected(CapturedClient)
    /// The device with this id disconnected.
    case clientDisconnected(String)
    /// Insert or replace this request row (in flight or finished).
    case requestUpdated(CapturedRequest)
    /// The listener cannot accept connections. Associated value is the reason.
    case listenerFailed(String)
    /// The listener accepts connections.
    case listenerReady
}
