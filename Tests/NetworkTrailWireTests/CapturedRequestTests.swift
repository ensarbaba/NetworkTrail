import Foundation
@testable import NetworkTrailWire
import Testing

struct CapturedRequestTests {
    @Test(arguments: [
        ("https://httpbin.org/get?probe=1", "/get?probe=1"),
        ("https://httpbin.org/post", "/post"),
        ("https://httpbin.org", "/"),
        ("https://httpbin.org/redirect-to?url=%2Fget", "/redirect-to?url=%2Fget"),
    ])
    func pathAndQueryKeepsPathAndQueryAsSent(url: String, expected: String) {
        #expect(makeRequest(url: url).pathAndQuery == expected)
    }

    @Test func pathAndQueryFallsBackToTheFullTextWithoutAHost() {
        #expect(makeRequest(url: "not a url").pathAndQuery == "not a url")
    }

    private func makeRequest(url: String) -> CapturedRequest {
        CapturedRequest(
            id: UUID(),
            clientID: "com.example.Demo|SIM-A",
            createdAt: Date(),
            method: "GET",
            url: url,
            statusCode: nil,
            duration: nil,
            requestHeaders: [:],
            responseHeaders: [:],
            requestBody: nil,
            responseBody: nil,
            errorDescription: nil,
            isComplete: false
        )
    }
}
