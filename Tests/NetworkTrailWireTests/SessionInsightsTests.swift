import Foundation
@testable import NetworkTrailWire
import Testing

struct SessionInsightsTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 0)
    private static let cannotFindHost = CapturedError(domain: NSURLErrorDomain, code: -1003, debugDescription: "")
    private static let cancelled = CapturedError(domain: NSURLErrorDomain, code: -999, debugDescription: "")

    @Test(arguments: [
        (200, nil, false),
        (302, nil, false),
        (404, nil, true),
        (500, nil, true),
        (599, nil, true),
        (nil, cannotFindHost, true),
        (nil, cancelled, false),
        (nil, nil, false), // In flight.
    ] as [(Int?, CapturedError?, Bool)])
    func failedIsAnErrorStatusOrAnErrorWithoutResponse(status: Int?, error: CapturedError?, isFailed: Bool) {
        let request = call(at: 0, status: status, error: error)

        #expect(SessionInsights(requests: [request], limits: .defaults).failed == (isFailed ? [request.id] : []))
    }

    @Test func slowIsAFinishedCallLongerThanTheLimit() {
        let inFlight = call(at: 0, status: nil)
        let atLimit = call(at: 1, duration: 1)
        let overLimit = call(at: 2, duration: 1.001)
        let requests = [inFlight, atLimit, overLimit]

        #expect(SessionInsights(requests: requests, limits: .defaults).slow == [overLimit.id])
        #expect(SessionInsights(requests: requests, limits: limits(slow: 0.5)).slow == [atLimit.id, overLimit.id])
    }

    @Test func duplicateRepeatsTheLatestSameCallInTheWindow() {
        let first = call(at: 0)
        let second = call(at: 0.5)
        let third = call(at: 1)
        let afterAPause = call(at: 3.5) // 2.5 s after the third call.
        let again = call(at: 5.5) // Exactly at the 2 s limit.
        let requests = [first, second, third, afterAPause, again]

        #expect(SessionInsights(requests: requests, limits: .defaults).duplicates == [
            second.id: Self.start,
            third.id: Self.start.addingTimeInterval(0.5),
            again.id: Self.start.addingTimeInterval(3.5),
        ])
        #expect(SessionInsights(requests: requests, limits: limits(window: 0.4)).duplicates.isEmpty)
    }

    @Test func duplicateNeedsTheSameAppMethodURLAndBody() {
        let requests = [
            call(at: 0, body: "a"),
            call(at: 0.1, method: "POST", body: "a"),
            call(at: 0.2, url: "https://example.com/items?page=2", body: "a"),
            call(at: 0.3, body: "b"),
            call(at: 0.4, body: "a", client: "other app"),
        ]

        #expect(SessionInsights(requests: requests, limits: .defaults).duplicates.isEmpty)
    }

    @Test func orderOfTheRequestsDoesNotMatter() {
        let requests = [call(at: 0), call(at: 0.5, status: 500), call(at: 1, duration: 3)]

        #expect(
            SessionInsights(requests: requests.reversed(), limits: .defaults)
                == SessionInsights(requests: requests, limits: .defaults)
        )
    }

    private func limits(slow: TimeInterval = 1, window: TimeInterval = 2) -> HealthLimits {
        HealthLimits(slowDuration: slow, duplicateWindow: window)
    }

    /// A finished 200 GET of the same app, unless the arguments change it.
    /// Without a status and an error, the call is in flight.
    private func call(
        at seconds: TimeInterval,
        method: String = "GET",
        url: String = "https://example.com/items?page=1",
        body: String? = nil,
        client: String = "app",
        status: Int? = 200,
        duration: TimeInterval? = 0.1,
        error: CapturedError? = nil
    ) -> CapturedRequest {
        let isComplete = status != nil || error != nil
        return CapturedRequest(
            id: UUID(),
            clientID: client,
            clientLaunchedAt: Self.start,
            createdAt: Self.start.addingTimeInterval(seconds),
            method: method,
            url: url,
            statusCode: status,
            duration: isComplete ? duration : nil,
            requestHeaders: [:],
            responseHeaders: [:],
            requestBody: body.map { Data($0.utf8) },
            responseBody: nil,
            error: error,
            isComplete: isComplete
        )
    }
}
