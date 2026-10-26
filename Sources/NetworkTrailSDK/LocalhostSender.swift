#if DEBUG
import Combine
import Foundation
import Network
import Pulse

/// Sends captured `URLSession` events from a Simulator app to the Mac app on `LocalhostEndpoint`.
///
/// Pulse `RemoteLogger` can only connect to a server that Bonjour finds. A Simulator app runs on the Mac,
/// so this sender connects to `127.0.0.1` directly: no Bonjour, no Info.plist keys.
/// Packets use the Pulse `RemoteLogger` format, so the Mac reads them the same way.
/// `NetworkTrail` owns the task that calls `run()`, and cancels that task to stop.
actor LocalhostSender {
    /// Bytes of packets kept while the Mac app is not connected. The oldest packets go first.
    private static let maxPendingBytes = 20 * 1024 * 1024
    /// Events that wait while the sender encodes the previous event. The oldest events go first.
    private static let maxBufferedEvents = 100
    /// Wait before the next connection attempt. The Mac app can start after the iOS app.
    private static let retryDelay: Duration = .seconds(2)
    /// Queue for the `NWConnection` callbacks. The callbacks only feed async streams.
    private static let networkQueue = DispatchQueue(label: "NetworkTrail.LocalhostSender")

    /// Set only while the connection is ready.
    private var connection: NWConnection?
    private var pendingPackets: [Data] = []
    private var pendingBytes = 0

    /// Forward `LoggerStore.shared` network events and keep the connection open, until the task is cancelled.
    func run() async {
        async let forwarding: Void = forwardEvents()
        async let connecting: Void = keepConnected()
        _ = await (forwarding, connecting)
    }

    /// `LoggerStore.events` is a Combine subject. The buffer keeps the newest events while the sender is busy.
    private func forwardEvents() async {
        let events = LoggerStore.shared.events
            .buffer(size: Self.maxBufferedEvents, prefetch: .keepFull, whenFull: .dropOldest)
            .values
        for await event in events {
            if let packet = event.packet {
                send(packet)
            }
        }
    }

    /// Connect, send the hello and the waiting packets, and wait until the connection closes. Then repeat.
    private func keepConnected() async {
        while !Task.isCancelled {
            if let readyConnection = await NWConnection.openLocalhost(queue: Self.networkQueue) {
                connection = readyConnection
                readyConnection.send(
                    content: ClientHello.current().packet,
                    completion: .contentProcessed { _ in }
                )
                let packets = pendingPackets
                pendingPackets.removeAll()
                pendingBytes = 0
                packets.forEach(send)
                await readyConnection.waitUntilClosed()
                connection = nil
                readyConnection.cancel()
            }
            try? await Task.sleep(for: Self.retryDelay)
        }
    }

    private func send(_ packet: Data) {
        guard let connection else {
            pendingPackets.append(packet)
            pendingBytes += packet.count
            while pendingBytes > Self.maxPendingBytes, !pendingPackets.isEmpty {
                pendingBytes -= pendingPackets.removeFirst().count
            }
            return
        }
        connection.send(content: packet, completion: .contentProcessed { _ in })
    }
}
#endif
