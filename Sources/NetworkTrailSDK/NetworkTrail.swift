#if DEBUG
import Pulse
import PulseProxy

/// Debug-only API: captures `URLSession` traffic and sends it to the NetworkTrail Mac app.
///
/// Pulse captures the traffic (`PulseProxy`). In the Simulator, `LocalhostSender` sends it to the Mac app
/// on `127.0.0.1`. On a device, Pulse `RemoteLogger` finds the Mac app through Bonjour (`_pulse._tcp`).
@MainActor
public enum NetworkTrail {
    /// `NetworkLogger.enableProxy()` swizzles `URLSession` and must run only once per process.
    private static var isProxyEnabled = false
    #if targetEnvironment(simulator)
    private static var senderTask: Task<Void, Never>?
    #endif

    /// Start capture and sending. Safe to call again, also after `stop()`.
    public static func start() {
        if !isProxyEnabled {
            NetworkLogger.enableProxy()
            isProxyEnabled = true
        }
        #if targetEnvironment(simulator)
        guard senderTask == nil else { return }
        senderTask = Task { await LocalhostSender().run() }
        #else
        let remote = RemoteLogger.shared
        remote.isAutomaticConnectionEnabled = true
        remote.initialize(store: .shared)
        remote.enable()
        #endif
    }

    /// Stop sending to the Mac app. The `URLSession` capture keeps running in this process.
    public static func stop() {
        #if targetEnvironment(simulator)
        senderTask?.cancel()
        senderTask = nil
        #else
        RemoteLogger.shared.disable()
        #endif
    }
}
#endif
