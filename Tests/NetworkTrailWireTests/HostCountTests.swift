import Foundation
@testable import NetworkTrailWire
import Testing

struct HostCountTests {
    @Test func hostsAreSortedAToZAndNotByCount() {
        let requests = ["https://b.example.com/1", "https://b.example.com/2", "https://b.example.com/3", "https://a.example.com/"]
            .map(request(to:))

        #expect(HostCount.make(from: requests) == [
            HostCount(host: "a.example.com", count: 1),
            HostCount(host: "b.example.com", count: 3),
        ])
    }

    @Test func hostsThatDifferOnlyInCaseAreOneRow() {
        let requests = [request(to: "https://API.example.com/a"), request(to: "https://api.example.com/b")]

        #expect(HostCount.make(from: requests) == [HostCount(host: "api.example.com", count: 2)])
    }

    @Test func listedHostsWithoutRequestsHaveACountOfZero() {
        let requests = [request(to: "https://b.example.com/")]

        #expect(HostCount.make(from: requests, alsoListing: ["c.example.com", "b.example.com"]) == [
            HostCount(host: "b.example.com", count: 1),
            HostCount(host: "c.example.com", count: 0),
        ])
    }

    @Test func noRequestsAndNoListedHostsGiveNoRows() {
        #expect(HostCount.make(from: []).isEmpty)
    }

    private func request(to url: String) -> CapturedRequest {
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
