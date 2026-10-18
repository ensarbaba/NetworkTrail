import SwiftUI

/// Sample iOS app in this repo. It uses NetworkTrail only through the Simulator snippet:
/// no Swift package and no Info.plist change.
@main
struct DemoApp: App {
    init() {
        // NetworkTrail: run once at launch, for example in App.init or application(_:didFinishLaunchingWithOptions:).
        #if DEBUG && targetEnvironment(simulator)
        Bundle(path: "/Applications/NetworkTrail.app/Contents/Frameworks/NetworkTrailDebug.framework")?.load()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            DemoContentView()
        }
    }
}
