/// Swift that the developer pastes once into the iOS app. No Swift package, no Info.plist change.
///
/// In a Debug build in the Simulator, the snippet loads `NetworkTrailDebug.framework` from NetworkTrail.app.
/// The framework starts the capture by itself when it loads. Release builds and devices skip the snippet.
enum SimulatorSnippet {
    /// Fixed path, the same on every Mac, so a team can share the snippet. NetworkTrail.app must be in /Applications.
    static let frameworkPath = "/Applications/NetworkTrail.app/Contents/Frameworks/NetworkTrailDebug.framework"

    static let source = """
        // NetworkTrail: run once at launch, for example in App.init or application(_:didFinishLaunchingWithOptions:).
        #if DEBUG && targetEnvironment(simulator)
        Bundle(path: "\(frameworkPath)")?.load()
        #endif
        """
}
