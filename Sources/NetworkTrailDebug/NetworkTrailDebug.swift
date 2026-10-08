import Foundation
#if DEBUG
import NetworkTrailSDK
#endif

/// Called from Objective-C `+load` when `NetworkTrailDebug.framework` is dlopened.
///
/// `+load` enqueues this on the main queue so `start()` runs after dyld finishes the load.
/// Capture stays inside `NetworkTrail.start()`’s `#if DEBUG`.
@_cdecl("NetworkTrailDebugStartFromLoad")
public func NetworkTrailDebugStartFromLoad() {
    #if DEBUG
    if Thread.isMainThread {
        MainActor.assumeIsolated {
            NetworkTrail.start()
        }
    } else {
        DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                NetworkTrail.start()
            }
        }
    }
    #endif
}
