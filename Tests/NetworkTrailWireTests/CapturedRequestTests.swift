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

    @Test func queryItemsAreDecodedAndKeepURLOrder() {
        let items = makeRequest(url: "https://example.com/search?q=a%20b&tag=2&tag=1&flag").queryItems

        #expect(items == [
            URLQueryItem(name: "q", value: "a b"),
            URLQueryItem(name: "tag", value: "2"),
            URLQueryItem(name: "tag", value: "1"),
            URLQueryItem(name: "flag", value: nil),
        ])
    }

    @Test func queryItemsAreEmptyWithoutAQuery() {
        #expect(makeRequest(url: "https://example.com/post").queryItems.isEmpty)
    }

    private func makeRequest(url: String) -> CapturedRequest {
        CapturedRequest(
            id: UUID(),
            clientID: "com.example.Demo|SIM-A",
            clientLaunchedAt: Date(),
            createdAt: Date(),
            method: "GET",
            url: url,
            statusCode: nil,
            duration: nil,
            requestHeaders: [:],
            responseHeaders: [:],
            requestBody: nil,
            responseBody: nil,
            error: nil,
            isComplete: false
        )
    }
}
