#if DEBUG
import Foundation
import NetworkTrailProtocol
import Pulse

extension LoggerStore.Event {
    /// The packet for a network event. Nil for events that the Mac app does not show.
    var packet: Data? {
        switch self {
        case .networkTaskCreated(let created):
            try? PulsePacketCodec.encode(
                code: PulsePacketCode.storeEventNetworkTaskCreated.rawValue,
                body: JSONEncoder().encode(created)
            )
        case .networkTaskCompleted(let completed):
            try? PulsePacketCodec.encode(
                code: PulsePacketCode.storeEventNetworkTaskCompleted.rawValue,
                body: PulseNetworkMessageCodec.encode(completed)
            )
        default:
            nil
        }
    }
}
#endif
