#if DEBUG
import Foundation
import NetworkTrailProtocol

/// First packet on each connection. Same JSON keys as the Pulse `RemoteLogger` hello,
/// so the Mac decodes it with `LoggerStore.Info.DeviceInfo` and `LoggerStore.Info.AppInfo`.
struct ClientHello: Encodable {
    struct DeviceInfo: Encodable {
        let name: String
        let model: String
        let localizedModel: String
        let systemName: String
        let systemVersion: String
    }

    struct AppInfo: Encodable {
        let bundleIdentifier: String?
        let name: String?
        let version: String?
        let build: String?
    }

    let deviceId: String
    let deviceInfo: DeviceInfo
    let appInfo: AppInfo

    var packet: Data? {
        guard let body = try? JSONEncoder().encode(self) else { return nil }
        return try? PulsePacketCodec.encode(code: PulsePacketCode.clientHello.rawValue, body: body)
    }

    /// `<bundle ID>|<Simulator ID>`: the same app on the same Simulator sends the same ID in every launch,
    /// so the Mac app keeps one row for it. Outside the Simulator there is no `SIMULATOR_UDID`,
    /// so the ID is new for each launch.
    static let appID: String = {
        guard let simulatorID = ProcessInfo.processInfo.environment["SIMULATOR_UDID"] else { return UUID().uuidString }
        return appID(
            bundleID: Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName,
            simulatorID: simulatorID
        )
    }()

    static func appID(bundleID: String, simulatorID: String) -> String {
        "\(bundleID)|\(simulatorID)"
    }

    /// Device facts come from the `SIMULATOR_*` environment variables that every Simulator process has.
    static func current() -> ClientHello {
        let environment = ProcessInfo.processInfo.environment
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let model = environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulator"
        let info = Bundle.main.infoDictionary
        return ClientHello(
            deviceId: appID,
            deviceInfo: DeviceInfo(
                name: environment["SIMULATOR_DEVICE_NAME"] ?? "iOS Simulator",
                model: model,
                localizedModel: model,
                systemName: "iOS",
                systemVersion: "\(version.majorVersion).\(version.minorVersion)"
            ),
            appInfo: AppInfo(
                bundleIdentifier: Bundle.main.bundleIdentifier,
                name: info?["CFBundleDisplayName"] as? String ?? info?["CFBundleName"] as? String,
                version: info?["CFBundleShortVersionString"] as? String,
                build: info?["CFBundleVersion"] as? String
            )
        )
    }
}
#endif
