/// Swift the developer pastes into an iOS app so the Simulator can load NetworkTrailDebug without a Swift package.
///
/// Does not call `NetworkTrail.start()`.
enum SimulatorSnippet {
    /// Info.plist Bonjour comment plus the `#if DEBUG` `Bundle.load()` calls.
    static let source = """
        // Info.plist also needs NSLocalNetworkUsageDescription and NSBonjourServices set to _pulse._tcp.
        #if DEBUG
        let app = URL(fileURLWithPath: "/Applications/NetworkTrail.app")
        let framework = app.appendingPathComponent(
            "Contents/Frameworks/NetworkTrailDebug.framework"
        )
        Bundle(url: framework)?.load()
        #endif
        """
}
