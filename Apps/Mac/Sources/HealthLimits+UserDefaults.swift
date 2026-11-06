import Foundation
import NetworkTrailWire

/// The health limits in `UserDefaults`, so that they stay after NetworkTrail starts again.
extension HealthLimits {
    private static let slowDurationKey = "health.slowDuration"
    private static let duplicateWindowKey = "health.duplicateWindow"

    /// The saved limits. A limit that was never saved has its default value.
    static var saved: HealthLimits {
        let userDefaults = UserDefaults.standard
        return HealthLimits(
            slowDuration: userDefaults.object(forKey: slowDurationKey) as? TimeInterval ?? defaults.slowDuration,
            duplicateWindow: userDefaults.object(forKey: duplicateWindowKey) as? TimeInterval ?? defaults.duplicateWindow
        )
    }

    func save() {
        UserDefaults.standard.set(slowDuration, forKey: Self.slowDurationKey)
        UserDefaults.standard.set(duplicateWindow, forKey: Self.duplicateWindowKey)
    }
}
