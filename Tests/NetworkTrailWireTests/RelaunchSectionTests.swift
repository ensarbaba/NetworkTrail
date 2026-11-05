import Foundation
@testable import NetworkTrailWire
import Testing

struct RelaunchSectionTests {
    private let firstLaunch = Date(timeIntervalSince1970: 1_000)
    private let secondLaunch = Date(timeIntervalSince1970: 2_000)

    @Test func oneLaunchHasNoDivider() {
        let requests = [request("A", firstLaunch), request("A", firstLaunch)]

        let (top, sections) = RelaunchSection.split(requests)

        #expect(top == requests)
        #expect(sections.isEmpty)
    }

    @Test func relaunchPutsADividerBetweenTheLaunches() {
        let new = [request("A", secondLaunch), request("A", secondLaunch)]
        let old = [request("A", firstLaunch), request("A", firstLaunch)]

        let (top, sections) = RelaunchSection.split(new + old)

        #expect(top == new)
        #expect(sections.count == 1)
        #expect(sections.first?.clientID == "A")
        #expect(sections.first?.launchedAt == secondLaunch)
        #expect(sections.first?.requests == old)
    }

    @Test func dividerSitsBelowTheOldestRequestOfTheNewLaunch() {
        // Newest first: B relaunched after A relaunched.
        let b2 = request("B", secondLaunch)
        let a2 = request("A", secondLaunch)
        let b1 = request("B", firstLaunch)
        let a1 = request("A", firstLaunch)

        let (top, sections) = RelaunchSection.split([b2, a2, b1, a1])

        #expect(top == [b2])
        #expect(sections.map(\.clientID) == ["B", "A"])
        #expect(sections.map(\.requests) == [[a2], [b1, a1]])
    }

    @Test func relaunchWithoutOlderRequestsOfThatAppHasNoDivider() {
        // After Clear for app A, only its new launch is in the list.
        let requests = [request("A", secondLaunch), request("B", firstLaunch)]

        let (top, sections) = RelaunchSection.split(requests)

        #expect(top == requests)
        #expect(sections.isEmpty)
    }

    @Test func emptyListHasNoRequests() {
        let (top, sections) = RelaunchSection.split([])

        #expect(top.isEmpty)
        #expect(sections.isEmpty)
    }

    private func request(_ clientID: String, _ launchedAt: Date) -> CapturedRequest {
        CapturedRequest(
            id: UUID(),
            clientID: clientID,
            clientLaunchedAt: launchedAt,
            createdAt: Date(),
            method: "GET",
            url: "https://example.com/",
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
