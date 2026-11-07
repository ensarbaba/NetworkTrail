import Foundation
@testable import NetworkTrailWire
import Testing

struct RequestResponseTextBuilderTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 0)
    private static let client = CapturedClient(
        id: "com.example.Demo|SIM-A",
        deviceName: "iPhone 18 Pro",
        appName: "Demo",
        bundleIdentifier: "com.example.Demo",
        systemVersion: "27.0"
    )

    @Test func finishedCallIsOneBlockWithRequestAndResponse() {
        let request = call(
            method: "POST",
            requestHeaders: ["Content-Type": "application/json", "accept": "*/*"],
            requestBody: #"{"name":"a","n":1.50}"#,
            status: 201,
            responseHeaders: ["Content-Type": "text/plain"],
            responseBody: "ok"
        )

        #expect(text(of: request) == #"""
            ```
            # Demo · iPhone 18 Pro, 27.0
            # 2001-01-01T01:00:00.000+01:00 · 420 ms

            POST https://example.com/items
            accept: */*
            Content-Type: application/json

            {
              "name": "a",
              "n": 1.50
            }

            HTTP 201
            Content-Type: text/plain

            ok
            ```
            """#)
    }

    @Test func callInFlightWaitsForTheResponse() {
        #expect(text(of: call(status: nil), client: nil) == """
            ```
            # 2001-01-01T01:00:00.000+01:00

            GET https://example.com/items

            # Waiting for response.
            ```
            """)
    }

    @Test func callWithoutResponseShowsTheError() {
        let debugText = #"Error Domain=NSURLErrorDomain Code=-1003 "(null)" UserInfo={}"#
        let error = CapturedError(domain: NSURLErrorDomain, code: -1003, debugDescription: debugText)
        var withoutError = call(status: nil)
        withoutError.isComplete = true

        #expect(text(of: call(status: nil, error: error)).hasSuffix("""
            GET https://example.com/items

            # No response: Cannot find host (NSURLErrorDomain -1003)
            \(debugText)
            ```
            """))
        #expect(text(of: withoutError).hasSuffix("GET https://example.com/items\n\n# No response.\n```"))
    }

    @Test func callWithStatusAndErrorShowsBoth() {
        let debugText = #"Error Domain=NSURLErrorDomain Code=-1005 "The network connection was lost." UserInfo={}"#
        let error = CapturedError(domain: NSURLErrorDomain, code: -1005, debugDescription: debugText)

        #expect(text(of: call(status: 200, error: error)).hasSuffix("""
            HTTP 200

            # Error: The network connection was lost. (NSURLErrorDomain -1005)
            \(debugText)
            ```
            """))
    }

    @Test func bodyLongerThanTheLimitIsCutBetweenCharacters() {
        // 16383 bytes of "a", then "é" (2 bytes): "é" does not fit into the 16384 bytes.
        let long = String(repeating: "a", count: 16383) + "é"
        let atLimit = String(repeating: "a", count: 16384)

        let longText = text(of: call(requestBody: long))
        let atLimitText = text(of: call(requestBody: atLimit))

        #expect(longText.contains(
            "\n\n\(String(repeating: "a", count: 16383))\n# Only the first 16383 of 16385 bytes of this body are shown.\n\nHTTP 200"
        ))
        #expect(atLimitText.contains("\n\n\(atLimit)\n\nHTTP 200"))
        #expect(!atLimitText.contains("Only the first"))
    }

    @Test func binaryBodyIsNotIncluded() {
        var request = call()
        request.responseBody = Data([0x00, 0xFF, 0xFE])

        #expect(text(of: request).hasSuffix("HTTP 200\n\n# Binary data, 3 bytes. Not included.\n```"))
    }

    @Test func fenceIsLongerThanTheBackticksInTheText() {
        let copied = text(of: call(requestBody: "a ``` b"))

        #expect(copied.hasPrefix("````\n"))
        #expect(copied.contains("\n\na ``` b\n\n"))
        #expect(copied.hasSuffix("\n````"))
    }

    private func text(of request: CapturedRequest, client: CapturedClient? = Self.client) -> String {
        RequestResponseTextBuilder.make(from: request, client: client, timeZone: TimeZone(secondsFromGMT: 3600)!)
    }

    /// A finished 200 GET without headers and bodies, unless the arguments change it.
    /// Without a status and an error, the call is in flight.
    private func call(
        method: String = "GET",
        requestHeaders: [String: String] = [:],
        requestBody: String? = nil,
        status: Int? = 200,
        responseHeaders: [String: String] = [:],
        responseBody: String? = nil,
        error: CapturedError? = nil
    ) -> CapturedRequest {
        let isComplete = status != nil || error != nil
        return CapturedRequest(
            id: UUID(),
            clientID: Self.client.id,
            clientLaunchedAt: Self.start,
            createdAt: Self.start,
            method: method,
            url: "https://example.com/items",
            statusCode: status,
            duration: isComplete ? 0.42 : nil,
            requestHeaders: requestHeaders,
            responseHeaders: responseHeaders,
            requestBody: requestBody.map { Data($0.utf8) },
            responseBody: responseBody.map { Data($0.utf8) },
            error: error,
            isComplete: isComplete
        )
    }
}
