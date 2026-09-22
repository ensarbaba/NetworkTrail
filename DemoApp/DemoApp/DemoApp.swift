import SwiftUI
#if DEBUG
import NetworkTrailSDK
#endif

/// Sample iOS app in this repo. DEBUG builds call `NetworkTrail.start()` so traffic can reach the Mac.
@main
struct DemoApp: App {
    init() {
        #if DEBUG
        Task { @MainActor in
            NetworkTrail.start()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            DemoContentView()
        }
    }
}
