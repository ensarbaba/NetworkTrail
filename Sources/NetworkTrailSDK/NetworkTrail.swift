#if DEBUG
import Foundation
import Pulse
import PulseProxy

/// Debug-only phone API. Call `NetworkTrail.start()` from your app; do not ship this in Release.
///
/// There is no custom probe. Pulse captures `URLSession` (via PulseProxy) and Pulse `RemoteLogger`
/// finds a Mac advertising `_pulse._tcp`. The Mac UI is a separate process.
public enum NetworkTrail {
    private static var didStart = false

    /// Turn on Pulse `URLSession` capture and Pulse RemoteLogger so this phone can find the Mac.
    ///
    /// `NetworkLogger.enableProxy()` swizzles `URLSession` (DEBUG only). Then `RemoteLogger` is
    /// enabled with automatic connection: the phone browses `_pulse._tcp` and connects to one
    /// NetworkTrail Mac. Safe to call twice; the second call does nothing.
    @MainActor
    public static func start() {
        guard !didStart else { return }
        didStart = true

        NetworkLogger.enableProxy()
        let remote = RemoteLogger.shared
        remote.isAutomaticConnectionEnabled = true
        remote.initialize(store: .shared)
        remote.enable()
    }

    /// Stop sending events to the Mac. Local Pulse capture may keep running in this process.
    @MainActor
    public static func stop() {
        RemoteLogger.shared.disable()
    }
}
#endif
