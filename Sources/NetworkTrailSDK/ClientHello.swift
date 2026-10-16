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

    let deviceId: UUID
    let deviceInfo: DeviceInfo
    let appInfo: AppInfo

    var packet: Data? {
        guard let body = try? JSONEncoder().encode(self) else { return nil }
        return try? PulsePacketCodec.encode(code: PulsePacketCode.clientHello.rawValue, body: body)
    }

    /// Device facts come from the `SIMULATOR_*` environment variables that every Simulator process has.
    static func current(clientID: UUID) -> ClientHello {
        let environment = ProcessInfo.processInfo.environment
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let model = environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulator"
        let info = Bundle.main.infoDictionary
        return ClientHello(
            deviceId: clientID,
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
