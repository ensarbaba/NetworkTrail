import Foundation

/// A relaunch divider in the request list, and the requests below it down to the next divider.
///
/// The requests above the divider come from the new launch of the app. The requests of that app below it
/// come from an earlier launch.
public struct RelaunchSection: Identifiable, Sendable {
    /// The app that relaunched.
    public let clientID: CapturedClient.ID
    /// The start of the new launch.
    public let launchedAt: Date
    /// Newest first. Never empty.
    public let requests: [CapturedRequest]

    /// The ID of the oldest request. It does not change when new requests arrive at the top of the list.
    public var id: CapturedRequest.ID { requests[requests.count - 1].id }

    /// Split a newest-first request list where an app relaunched.
    ///
    /// A divider goes directly below the oldest request of a launch, if the list also has a request of the same
    /// app from an earlier launch. The rule reads only the requests in the list: after Clear or a search,
    /// a relaunch without older requests of that app in the list has no divider.
    ///
    /// Returns the requests above every divider, and each divider with its requests, from top to bottom.
    public static func split(_ requests: [CapturedRequest]) -> (top: [CapturedRequest], sections: [RelaunchSection]) {
        var sections: [RelaunchSection] = []
        // Walk from the oldest request to the newest. `requestsSinceDivider` is oldest first.
        var requestsSinceDivider: [CapturedRequest] = []
        var latestLaunches: [CapturedClient.ID: Date] = [:]
        for request in requests.reversed() {
            if let latestLaunch = latestLaunches[request.clientID], latestLaunch != request.clientLaunchedAt {
                sections.append(RelaunchSection(
                    clientID: request.clientID,
                    launchedAt: request.clientLaunchedAt,
                    requests: requestsSinceDivider.reversed()
                ))
                requestsSinceDivider = []
            }
            latestLaunches[request.clientID] = request.clientLaunchedAt
            requestsSinceDivider.append(request)
        }
        return (requestsSinceDivider.reversed(), sections.reversed())
    }
}
