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
    /// The launch of the app that sent this request, from the hello of its connection.
    public var clientLaunchedAt: Date
    public var createdAt: Date
    public var method: String
    public var url: String
    public var statusCode: Int?
    public var duration: TimeInterval?
    public var requestHeaders: [String: String]
    public var responseHeaders: [String: String]
    public var requestBody: Data?
    public var responseBody: Data?
    /// Set when the call ended with an error, with or without a response.
    public var error: CapturedError?
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

    /// The query of `url` as names and values, in URL order and percent-decoded. Empty without a query.
    public var queryItems: [URLQueryItem] {
        URLComponents(string: url)?.queryItems ?? []
    }
}

/// The error that ended a call, as the app reported it.
public struct CapturedError: Hashable, Sendable {
    public var domain: String
    public var code: Int
    /// `NSError.debugDescription` from the app: domain, code, message, and user info.
    public var debugDescription: String

    /// A short title: the message of the app, or else the name of an `NSURLErrorDomain` code ("Cannot find host"),
    /// or else "<domain> error <code>".
    ///
    /// The Mac cannot make a message from the code: there, `NSError(domain:code:)` gives only
    /// "The operation couldn’t be completed.".
    public var title: String {
        if let message { return message }
        if domain == NSURLErrorDomain, let name = Self.urlErrorNames[URLError.Code(rawValue: code)] { return name }
        return "\(domain) error \(code)"
    }

    /// The message in `debugDescription`, for example "A server with the specified hostname could not be found.".
    /// Nil if the `NSError` text has no message: the iOS 27 Simulator sends `"(null)"` there.
    /// A text that is not in the `NSError` format is the message as it is.
    var message: String? {
        // Format: Error Domain=<domain> Code=<code> "<message>" UserInfo={…}
        guard debugDescription.hasPrefix("Error Domain=") else {
            return debugDescription.isEmpty ? nil : debugDescription
        }
        guard let start = debugDescription.range(of: "Code=\(code) \"")?.upperBound else { return nil }
        let rest = debugDescription[start...]
        let end = rest.range(of: "\" UserInfo=")?.lowerBound ?? (rest.hasSuffix("\"") ? rest.index(before: rest.endIndex) : nil)
        guard let end else { return nil }
        let text = String(rest[..<end])
        return text.isEmpty || text == "(null)" ? nil : text
    }

    /// Short names for the `URLError` codes, from the names of the `URLError.Code` constants.
    private static let urlErrorNames: [URLError.Code: String] = [
        .unknown: "Unknown error",
        .cancelled: "Cancelled",
        .badURL: "Bad URL",
        .timedOut: "Timed out",
        .unsupportedURL: "Unsupported URL",
        .cannotFindHost: "Cannot find host",
        .cannotConnectToHost: "Cannot connect to host",
        .networkConnectionLost: "Network connection lost",
        .dnsLookupFailed: "DNS lookup failed",
        .httpTooManyRedirects: "Too many HTTP redirects",
        .resourceUnavailable: "Resource unavailable",
        .notConnectedToInternet: "Not connected to the internet",
        .redirectToNonExistentLocation: "Redirect to a location that does not exist",
        .badServerResponse: "Bad server response",
        .userCancelledAuthentication: "User cancelled authentication",
        .userAuthenticationRequired: "User authentication required",
        .zeroByteResource: "Zero-byte resource",
        .cannotDecodeRawData: "Cannot decode raw data",
        .cannotDecodeContentData: "Cannot decode content data",
        .cannotParseResponse: "Cannot parse response",
        .appTransportSecurityRequiresSecureConnection: "App Transport Security requires a secure connection",
        .fileDoesNotExist: "File does not exist",
        .fileIsDirectory: "File is a directory",
        .noPermissionsToReadFile: "No permission to read the file",
        .dataLengthExceedsMaximum: "Data length exceeds the maximum",
        .secureConnectionFailed: "Secure connection failed",
        .serverCertificateHasBadDate: "Server certificate has a bad date",
        .serverCertificateUntrusted: "Server certificate not trusted",
        .serverCertificateHasUnknownRoot: "Server certificate has an unknown root",
        .serverCertificateNotYetValid: "Server certificate not yet valid",
        .clientCertificateRejected: "Client certificate rejected",
        .clientCertificateRequired: "Client certificate required",
        .cannotLoadFromNetwork: "Cannot load from the network",
        .cannotCreateFile: "Cannot create the file",
        .cannotOpenFile: "Cannot open the file",
        .cannotCloseFile: "Cannot close the file",
        .cannotWriteToFile: "Cannot write to the file",
        .cannotRemoveFile: "Cannot remove the file",
        .cannotMoveFile: "Cannot move the file",
        .downloadDecodingFailedMidStream: "Download decoding failed during the stream",
        .downloadDecodingFailedToComplete: "Download decoding failed to complete",
        .internationalRoamingOff: "International roaming off",
        .callIsActive: "Call is active",
        .dataNotAllowed: "Data not allowed",
        .requestBodyStreamExhausted: "Request body stream exhausted",
        .backgroundSessionRequiresSharedContainer: "Background session requires a shared container",
        .backgroundSessionInUseByAnotherProcess: "Background session in use by another process",
        .backgroundSessionWasDisconnected: "Background session was disconnected",
    ]
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
