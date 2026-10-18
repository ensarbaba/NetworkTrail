import CryptoKit
import Foundation
import Network
import NetworkTrailProtocol
import Pulse

/// Settings for the Mac listener: the name shown on the local network, and an optional shared password.
///
/// If `passcode` is nil or empty, connections are plain TCP. If it is set, both sides use Pulse’s
/// pre-shared-key TLS (same password the phone types in). This is not a custom probe.
public struct PulseListenerConfiguration: Sendable {
    /// Bonjour instance name (this Mac), not the service type. Two Macs must use different names.
    public var serviceName: String
    /// Optional Pulse shared password. Nil means no TLS.
    public var passcode: String?

    /// Default instance name is `NetworkTrail (<this Mac>)` so two computers are two servers.
    /// Pass `serviceName` to override. Pass a passcode only if the phone is also using one.
    public init(serviceName: String = PulseListenerConfiguration.defaultServiceName(), passcode: String? = nil) {
        self.serviceName = serviceName
        self.passcode = passcode
    }

    /// Unique default: `NetworkTrail (iMac)` style. Service type stays `_pulse._tcp`; the phone still picks one Mac.
    public static func defaultServiceName() -> String {
        let raw = Host.current().localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let host: String
        if let raw, !raw.isEmpty {
            host = raw
        } else {
            let hostname = ProcessInfo.processInfo.hostName.trimmingCharacters(in: .whitespacesAndNewlines)
            host = hostname.isEmpty ? "Mac" : hostname
        }
        return bonjourInstanceName(hostName: host)
    }

    /// DNS-SD instance names are at most 63 bytes. Keep the `NetworkTrail (…)` shape and shorten the host part.
    static func bonjourInstanceName(hostName: String) -> String {
        let prefix = "NetworkTrail ("
        let suffix = ")"
        let budget = 63 - prefix.utf8.count - suffix.utf8.count
        var host = hostName.isEmpty ? "Mac" : hostName
        while host.utf8.count > max(1, budget), host.count > 1 {
            host.removeLast()
        }
        if host.utf8.count > max(1, budget) {
            host = "Mac"
        }
        return prefix + host + suffix
    }
}

/// Mac-side Pulse remote logger: advertise on Bonjour, accept TCP, decode Pulse packets, notify the UI.
///
/// Service type is always `_pulse._tcp` (what Pulse’s phone `RemoteLogger` looks for). The instance
/// name is per Mac, so two inspectors on one network show up as two servers and the phone picks one.
/// We do not invent a new transport. Inbound bytes go through `PulsePacketCodec.decode`;
/// hello/ping/resume replies go through `PulsePacketCodec.encode`.
@MainActor
public final class PulseListenerServer: ObservableObject {
    /// Shared Bonjour service type `"_pulse._tcp"`. Instance name is `configuration.serviceName`.
    public static let serviceType = "_pulse._tcp"
    /// Version string we put in our hello reply so the phone knows we speak protocol 4.
    static let protocolVersionString = "4.0.0"

    /// True after Bonjour advertising is up, false if we failed, stopped, or cancelled.
    @Published public private(set) var isListening = false
    /// Last listener failure text, if any.
    @Published public private(set) var lastError: String?

    private let configuration: PulseListenerConfiguration
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: ClientConnection] = [:]
    private let onEvent: (@Sendable (SessionEvent) -> Void)?

    /// - Parameter onEvent: Called when a device connects/drops, a request row changes, or the listener
    ///   itself is ready or failed. The Mac UI (`SessionStore`) is the usual listener.
    public init(
        configuration: PulseListenerConfiguration = .init(),
        onEvent: (@Sendable (SessionEvent) -> Void)? = nil
    ) {
        self.configuration = configuration
        self.onEvent = onEvent
    }

    /// Advertise `_pulse._tcp` under this Mac’s instance name and accept TCP (or Pulse PSK TLS).
    /// Safe to call twice: the second call is ignored while a listener already exists.
    public func start() {
        guard listener == nil else { return }
        lastError = nil

        do {
            let parameters = makeParameters()
            let listener = try NWListener(
                using: parameters,
                on: NWEndpoint.Port(rawValue: LocalhostEndpoint.port)!
            )
            listener.service = NWListener.Service(
                name: configuration.serviceName,
                type: Self.serviceType
            )
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handleListenerState(state)
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.accept(connection)
                }
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            lastError = error.localizedDescription
            onEvent?(.listenerFailed(error.localizedDescription))
        }
    }

    /// Tear down Bonjour and close every phone connection.
    public func stop() {
        listener?.cancel()
        listener = nil
        isListening = false
        for connection in connections.values {
            connection.close()
        }
        connections.removeAll()
    }

    /// Plain TCP when there is no passcode; Pulse PSK TLS when there is one.
    private func makeParameters() -> NWParameters {
        if let passcode = configuration.passcode, !passcode.isEmpty {
            return NWParameters(pulsePasscode: passcode)
        }
        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 4
        let parameters = NWParameters(tls: nil, tcp: tcp)
        parameters.includePeerToPeer = true
        return parameters
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            isListening = true
            onEvent?(.listenerReady)
        case .failed(let error):
            isListening = false
            lastError = error.localizedDescription
            onEvent?(.listenerFailed(error.localizedDescription))
        case .cancelled:
            isListening = false
        default:
            break
        }
    }

    /// Wrap one accepted TCP connection as a `ClientConnection` and start reading packets.
    private func accept(_ nwConnection: NWConnection) {
        let client = ClientConnection(connection: nwConnection) { [weak self] event in
            Task { @MainActor in
                self?.handleClientEvent(event)
            }
        }
        connections[ObjectIdentifier(nwConnection)] = client
        client.start()
    }

    private func handleClientEvent(_ event: ClientConnection.Event) {
        switch event {
        case .disconnected(let connection):
            connections.removeValue(forKey: ObjectIdentifier(connection))
        case .inspector(let inspectorEvent):
            onEvent?(inspectorEvent)
        }
    }
}

// MARK: - Client connection

/// One phone’s TCP stream: handshake, pings, and HTTP created/completed events.
///
/// Reads: `PulsePacketCodec.decode` until a full packet is in the buffer.
/// Writes: `PulsePacketCodec.encode` then `NWConnection.send`.
/// Progress packets (`storeEventNetworkTaskProgressUpdated`) are ignored.
@MainActor
private final class ClientConnection {
    /// Either the socket died, or we have a `SessionEvent` to forward.
    enum Event {
        case disconnected(NWConnection)
        case inspector(SessionEvent)
    }

    private let connection: NWConnection
    private let onEvent: (Event) -> Void
    private var buffer = Data()
    private var clientID: UUID?
    private var pingTask: Task<Void, Never>?
    private var isClosed = false

    init(connection: NWConnection, onEvent: @escaping (Event) -> Void) {
        self.connection = connection
        self.onEvent = onEvent
    }

    /// Start the Network.framework connection and the receive loop.
    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleState(state)
            }
        }
        connection.start(queue: .main)
        receive()
    }

    /// The only exit path, for every reason the connection ends: stop the pings, cancel the socket,
    /// and report the disconnect. Runs once; later calls do nothing.
    func close() {
        guard !isClosed else { return }
        isClosed = true
        pingTask?.cancel()
        connection.cancel()
        if let clientID {
            onEvent(.inspector(.clientDisconnected(clientID)))
        }
        onEvent(.disconnected(connection))
    }

    private func handleState(_ state: NWConnection.State) {
        switch state {
        case .failed, .cancelled:
            close()
        default:
            break
        }
    }

    /// Keep reading TCP chunks until the connection ends.
    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_535) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }
                if let data, !data.isEmpty {
                    self.process(data: data)
                }
                if isComplete || error != nil {
                    self.close()
                } else {
                    self.receive()
                }
            }
        }
    }

    /// Append bytes, then `PulsePacketCodec.decode` as many complete packets as we can.
    /// Incomplete packets stay in `buffer` for the next chunk. Failed decode (`try?`) drops that attempt.
    private func process(data freshData: Data) {
        var freshData = freshData
        if buffer.isEmpty {
            while let (packet, size) = try? PulsePacketCodec.decode(buffer: freshData) {
                handle(packet: packet)
                if size == freshData.count { return }
                freshData.removeFirst(size)
            }
        }
        if !freshData.isEmpty {
            buffer.append(freshData)
            while let (packet, size) = try? PulsePacketCodec.decode(buffer: buffer) {
                handle(packet: packet)
                buffer.removeFirst(size)
            }
            if buffer.isEmpty { buffer = Data() }
        }
    }

    /// Handshake, heartbeat, and HTTP rows. Unknown codes and progress updates fall through `default` and are ignored.
    ///
    /// Method and URL come from `originalRequest`: what the app asked for, before any redirect.
    /// Headers come from `currentRequest`: what was sent, including `httpAdditionalHeaders` of the session.
    private func handle(packet: PulsePacket) {
        guard let code = PulsePacketCode(rawValue: packet.code) else { return }
        switch code {
        case .clientHello:
            handleClientHello(packet.body)
        case .ping:
            send(code: .ping)
        case .storeEventNetworkTaskCreated:
            if let event = try? JSONDecoder().decode(LoggerStore.Event.NetworkTaskCreated.self, from: packet.body),
               let clientID {
                let request = CapturedRequest(
                    id: event.taskId,
                    clientID: clientID,
                    createdAt: event.createdAt,
                    method: event.originalRequest.httpMethod ?? "GET",
                    url: event.originalRequest.url?.absoluteString ?? "",
                    statusCode: nil,
                    duration: nil,
                    requestHeaders: (event.currentRequest ?? event.originalRequest).headers ?? [:],
                    responseHeaders: [:],
                    requestBody: nil,
                    responseBody: nil,
                    errorDescription: nil,
                    isComplete: false
                )
                onEvent(.inspector(.requestUpdated(request)))
            }
        case .storeEventNetworkTaskCompleted:
            if let event = try? PulseNetworkMessageCodec.decode(packet.body),
               let clientID {
                let status = event.response?.statusCode
                let duration = event.metrics?.taskInterval.duration
                let request = CapturedRequest(
                    id: event.taskId,
                    clientID: clientID,
                    createdAt: event.createdAt,
                    method: event.originalRequest.httpMethod ?? "GET",
                    url: event.originalRequest.url?.absoluteString ?? "",
                    statusCode: status,
                    duration: duration,
                    requestHeaders: (event.currentRequest ?? event.originalRequest).headers ?? [:],
                    responseHeaders: event.response?.headers ?? [:],
                    requestBody: event.requestBody,
                    responseBody: event.responseBody,
                    errorDescription: event.error?.debugDescription,
                    isComplete: true
                )
                onEvent(.inspector(.requestUpdated(request)))
            }
        default:
            // Includes storeEventNetworkTaskProgressUpdated (upload/download bytes). Not shown in v1 UI.
            break
        }
    }

    /// Handshake: phone hello → we list the device, send our hello, tell it to resume events, then ping.
    private func handleClientHello(_ body: Data) {
        struct ClientHello: Codable {
            let version: String?
            let deviceId: UUID
            let deviceInfo: LoggerStore.Info.DeviceInfo
            let appInfo: LoggerStore.Info.AppInfo
        }
        guard let hello = try? JSONDecoder().decode(ClientHello.self, from: body) else { return }
        clientID = hello.deviceId
        let client = CapturedClient(
            id: hello.deviceId,
            deviceName: hello.deviceInfo.name,
            appName: hello.appInfo.name ?? "App",
            bundleIdentifier: hello.appInfo.bundleIdentifier ?? "—",
            systemVersion: hello.deviceInfo.systemVersion
        )
        onEvent(.inspector(.clientConnected(client)))

        let response = PulseServerHello(version: PulseListenerServer.protocolVersionString)
        send(code: .serverHello, entity: response)
        send(code: .resume)
        startPingLoop()
    }

    /// Heartbeat: encode a ping packet every two seconds so the phone knows the Mac is still here.
    private func startPingLoop() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { return }
                self.send(code: .ping)
            }
        }
    }

    private func send(code: PulsePacketCode) {
        send(code: code, body: Data())
    }

    private func send<T: Encodable>(code: PulsePacketCode, entity: T) {
        guard let body = try? JSONEncoder().encode(entity) else { return }
        send(code: code, body: body)
    }

    /// Reply path: `PulsePacketCodec.encode` then write on this TCP connection.
    private func send(code: PulsePacketCode, body: Data) {
        guard let data = try? PulsePacketCodec.encode(code: code.rawValue, body: body) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }
}

// MARK: - Optional shared-password TLS (Pulse PSK, not a custom probe)

/// Builds Network.framework TLS options that match Pulse’s phone passcode (pre-shared key).
/// Used only when `PulseListenerConfiguration.passcode` is non-empty; otherwise we use plain TCP.
private extension NWParameters {
    convenience init(pulsePasscode: String) {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 4
        self.init(tls: NWParameters.tlsOptions(passcode: pulsePasscode), tcp: tcpOptions)
        includePeerToPeer = true
    }

    private static func tlsOptions(passcode: String) -> NWProtocolTLS.Options {
        let tlsOptions = NWProtocolTLS.Options()
        let authenticationKey = SymmetricKey(data: passcode.data(using: .utf8)!)
        var authenticationCode = HMAC<SHA256>.authenticationCode(
            for: "PulseLoggerProtocol".data(using: .utf8)!,
            using: authenticationKey
        )
        let authenticationDispatchData = withUnsafeBytes(of: &authenticationCode) { pointer in
            DispatchData(bytes: pointer)
        }
        sec_protocol_options_add_pre_shared_key(
            tlsOptions.securityProtocolOptions,
            authenticationDispatchData as __DispatchData,
            DispatchData.make(string: "PulseLoggerProtocol") as __DispatchData
        )
        sec_protocol_options_append_tls_ciphersuite(
            tlsOptions.securityProtocolOptions,
            tls_ciphersuite_t(rawValue: UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256))!
        )
        return tlsOptions
    }
}

private extension DispatchData {
    static func make(string: String) -> DispatchData {
        let data = string.data(using: .unicode) ?? Data()
        return Swift.withUnsafeBytes(of: data) { pointer in
            DispatchData(bytes: UnsafeRawBufferPointer(start: pointer.baseAddress, count: data.count))
        }
    }
}
