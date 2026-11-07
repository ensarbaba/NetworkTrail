import Foundation

/// One row of the host filter: a host and the number of requests to it.
public struct HostCount: Identifiable, Equatable, Sendable {
    /// The host in lowercase (`CapturedRequest.hostKey`).
    public let host: String
    public let count: Int

    public var id: String { host }

    /// One row for each host of `requests`, and for each host of `alsoListing` (with 0 when it has no request),
    /// A to Z. Hosts that differ only in case are one row. The order never depends on the counts.
    public static func make(from requests: [CapturedRequest], alsoListing hosts: Set<String> = []) -> [HostCount] {
        var counts = Dictionary(hosts.map { ($0.lowercased(), 0) }, uniquingKeysWith: { first, _ in first })
        for request in requests {
            counts[request.hostKey, default: 0] += 1
        }
        return counts
            .map { HostCount(host: $0.key, count: $0.value) }
            .sorted { $0.host < $1.host }
    }
}

extension CapturedRequest {
    /// `host` in lowercase: the key of the host filter. A host does not depend on case.
    public var hostKey: String {
        host.lowercased()
    }
}
