/// Where the Mac app listens for Simulator apps. A Simulator app runs on the Mac, so `127.0.0.1` is the Mac.
///
/// No Bonjour, so the iOS app needs no Info.plist keys. Physical devices cannot use this address.
package enum LocalhostEndpoint {
    /// IPv4 loopback. Not the name `localhost`, which can resolve to `::1` first.
    package static let host = "127.0.0.1"
    /// Fixed TCP port of the Mac listener on `host`. The Simulator side connects here without discovery.
    package static let port: UInt16 = 43000
}
