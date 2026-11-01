import Foundation
import Network
import NetworkTrailProtocol
import Pulse

/// Mac-side listener for Simulator apps: accept TCP on `LocalhostEndpoint`, decode Pulse packets, notify the UI.
///
/// It binds only `127.0.0.1`, so only apps on this Mac can connect; Simulator apps run on this Mac.
/// The packets use the Pulse `RemoteLogger` format. Inbound bytes go through `PulsePacketCodec.decode`;
/// hello/ping/resume replies go through `PulsePacketCodec.encode`.
@MainActor
public final class PulseListenerServer {
    /// Version string we put in our hello reply so the phone knows we speak protocol 4.
    static let protocolVersionString = "4.0.0"

    private var listener: NWListener?
    private var connections: [ObjectIdentifier: ClientConnection] = [:]
    private let onEvent: (@Sendable (SessionEvent) -> Void)?

    /// - Parameter onEvent: Called when an app connects or drops, a request row changes, or the listener
    ///   itself is ready or failed. The Mac UI (`SessionStore`) is the usual listener.
    public init(onEvent: (@Sendable (SessionEvent) -> Void)? = nil) {
        self.onEvent = onEvent
    }

    /// Start accepting connections on `LocalhostEndpoint`. Safe to call twice: the second call is ignored
    /// while a listener already exists.
    public func start() {
        guard listener == nil else { return }
        do {
            let listener = try NWListener(using: Self.makeParameters())
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
            onEvent?(.listenerFailed(error.localizedDescription))
        }
    }

    /// Plain TCP bound to `127.0.0.1`, with keepalive so a dead peer is noticed even when no data flows.
    private static func makeParameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 4
        let parameters = NWParameters(tls: nil, tcp: tcp)
        parameters.requiredLocalEndpoint = .hostPort(
            host: NWEndpoint.Host(LocalhostEndpoint.host),
            port: NWEndpoint.Port(rawValue: LocalhostEndpoint.port)!
        )
        parameters.allowLocalEndpointReuse = true
        return parameters
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            onEvent?(.listenerReady)
        case .waiting(let error), .failed(let error):
            onEvent?(.listenerFailed(Self.reason(for: error)))
        default:
            break
        }
    }

    /// Reason for the UI. A port in use is the usual failure; its `NWError.localizedDescription` is long:
    /// "The operation couldn’t be completed. (Network.NWError error 48 - Address already in use)".
    private static func reason(for error: NWError) -> String {
        if case .posix(.EADDRINUSE) = error {
            return "port \(LocalhostEndpoint.port) is in use by another app"
        }
        return error.localizedDescription
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
    private var clientID: String?
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
            let deviceId: String
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
