import Foundation

/// The limits of the Slow and Duplicate rules.
public struct HealthLimits: Equatable, Sendable {
    /// A finished call that takes longer than this is slow.
    public var slowDuration: TimeInterval
    /// A call that repeats a call that started at most this long before it is a duplicate.
    public var duplicateWindow: TimeInterval

    public static let defaults = HealthLimits(slowDuration: 1, duplicateWindow: 2)

    public init(slowDuration: TimeInterval, duplicateWindow: TimeInterval) {
        self.slowDuration = slowDuration
        self.duplicateWindow = duplicateWindow
    }
}

/// The failed, slow, and duplicate calls in a list of requests.
///
/// - Failed: status 400–599, or an error without a response. A call that the app cancelled
///   (`URLError.cancelled`) is not failed.
/// - Slow: a finished call that took longer than `HealthLimits.slowDuration`.
/// - Duplicate: the same app, method, URL (with query), and request body as a call that started
///   at most `HealthLimits.duplicateWindow` before it. The first call of a group is not a duplicate,
///   so the count is the number of extra calls.
public struct SessionInsights: Equatable, Sendable {
    public let failed: Set<CapturedRequest.ID>
    public let slow: Set<CapturedRequest.ID>
    /// Each duplicate, with the start of the call that it repeats: the latest earlier call with the same key.
    public let duplicates: [CapturedRequest.ID: Date]

    /// `requests` can be in any order.
    public init(requests: [CapturedRequest], limits: HealthLimits) {
        var failed: Set<CapturedRequest.ID> = []
        var slow: Set<CapturedRequest.ID> = []
        var duplicates: [CapturedRequest.ID: Date] = [:]
        // The start of the latest call for each key.
        var latestStart: [CallKey: Date] = [:]
        for request in requests.sorted(by: { $0.createdAt < $1.createdAt }) {
            if Self.isFailed(request) {
                failed.insert(request.id)
            }
            if let duration = request.duration, duration > limits.slowDuration {
                slow.insert(request.id)
            }
            let key = CallKey(request)
            if let previousStart = latestStart[key],
               request.createdAt.timeIntervalSince(previousStart) <= limits.duplicateWindow {
                duplicates[request.id] = previousStart
            }
            latestStart[key] = request.createdAt
        }
        self.failed = failed
        self.slow = slow
        self.duplicates = duplicates
    }

    private static func isFailed(_ request: CapturedRequest) -> Bool {
        if let statusCode = request.statusCode {
            return (400...599).contains(statusCode)
        }
        guard let error = request.error else { return false }
        return !(error.domain == NSURLErrorDomain && error.code == URLError.cancelled.rawValue)
    }

    /// What makes two calls the same call.
    private struct CallKey: Hashable {
        let clientID: String
        let method: String
        let url: String
        let body: Data?

        init(_ request: CapturedRequest) {
            clientID = request.clientID
            method = request.method
            url = request.url
            body = request.requestBody
        }
    }
}
