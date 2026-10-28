#if DEBUG
import Pulse
import PulseProxy

/// Debug-only API: captures `URLSession` traffic and sends it to the NetworkTrail Mac app.
///
/// Pulse captures the traffic (`PulseProxy`), and `LocalhostSender` sends it to the Mac app on `127.0.0.1`.
/// That address is the Mac only for apps in the iOS Simulator.
@MainActor
public enum NetworkTrail {
    /// `NetworkLogger.enableProxy()` swizzles `URLSession` and must run only once per process.
    private static var isProxyEnabled = false
    private static var senderTask: Task<Void, Never>?

    /// Start capture and sending. Safe to call again, also after `stop()`.
    public static func start() {
        if !isProxyEnabled {
            NetworkLogger.enableProxy()
            isProxyEnabled = true
        }
        guard senderTask == nil else { return }
        senderTask = Task { await LocalhostSender().run() }
    }

    /// Stop sending to the Mac app. The `URLSession` capture keeps running in this process.
    public static func stop() {
        senderTask?.cancel()
        senderTask = nil
    }
}
#endif
