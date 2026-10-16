#if DEBUG
import Network
import NetworkTrailProtocol

extension NWConnection {
    /// Returns a ready connection to `LocalhostEndpoint`, or nil when the Mac app does not accept it.
    static func openLocalhost(queue: DispatchQueue) async -> NWConnection? {
        let connection = NWConnection(
            host: NWEndpoint.Host(LocalhostEndpoint.host),
            port: NWEndpoint.Port(rawValue: LocalhostEndpoint.port)!,
            using: .tcp
        )
        let states = AsyncStream<NWConnection.State> { continuation in
            connection.stateUpdateHandler = { continuation.yield($0) }
        }
        connection.start(queue: queue)
        for await state in states {
            switch state {
            case .ready:
                connection.stateUpdateHandler = nil
                return connection
            case .waiting, .failed, .cancelled:
                // `.waiting` on localhost means "connection refused": the Mac app is not running.
                connection.cancel()
                return nil
            default:
                continue
            }
        }
        connection.cancel()
        return nil
    }

    /// Read and drop incoming data. Returns when the peer closes the connection or the task is cancelled.
    func waitUntilClosed() async {
        await withTaskCancellationHandler {
            var isClosed = false
            while !isClosed {
                isClosed = await withCheckedContinuation { continuation in
                    receive(minimumIncompleteLength: 1, maximumLength: 65_536) { _, _, isComplete, error in
                        continuation.resume(returning: isComplete || error != nil)
                    }
                }
            }
        } onCancel: {
            cancel()
        }
    }
}
#endif
