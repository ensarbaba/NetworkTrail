import Foundation

/// A phone or Simulator that connected to the Mac inspector.
public struct CapturedClient: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var deviceName: String
    public var appName: String
    public var bundleIdentifier: String
    public var systemVersion: String
    public var connectedAt: Date

    /// Creates a client record when a device connects.
    public init(
        id: UUID,
        deviceName: String,
        appName: String,
        bundleIdentifier: String,
        systemVersion: String,
        connectedAt: Date = Date()
    ) {
        self.id = id
        self.deviceName = deviceName
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.systemVersion = systemVersion
        self.connectedAt = connectedAt
    }
}

/// One HTTP call as the Mac list shows it: method, URL, headers, bodies, and status when they exist.
///
/// Status, duration, and bodies are optional because the row can appear before the call finishes.
public struct CapturedRequest: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var clientID: UUID
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
}

/// News from the Bonjour listener for the Mac app to apply: devices, requests, or listener health.
public enum InspectorStoreEvent: Sendable {
    /// A device connected.
    case clientConnected(CapturedClient)
    /// The device with this id disconnected.
    case clientDisconnected(UUID)
    /// Insert or replace this request row (in flight or finished).
    case requestUpdated(CapturedRequest)
    /// The listener could not start. Associated value is the error text.
    case listenerFailed(String)
    /// The listener is up and advertising on the local network.
    case listenerReady
}
