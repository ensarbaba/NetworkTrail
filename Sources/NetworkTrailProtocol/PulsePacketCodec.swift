// Compatible with Pulse RemoteLogger (MIT, Alexander Grebenyuk). See NOTICE.

import Foundation
import Pulse

/// One-byte labels for each kind of message on the wire.
package enum PulsePacketCode: UInt8 {
    /// Phone introducing itself.
    case clientHello = 0
    /// Mac answering the hello.
    case serverHello = 1
    /// Phone should stop sending store events.
    case pause = 2
    /// Phone should start sending store events again.
    case resume = 3
    /// Keep-alive.
    case ping = 6
    /// A log message was stored.
    case storeEventMessageStored = 7
    /// An HTTP call started.
    case storeEventNetworkTaskCreated = 8
    /// Bytes transferred for an HTTP call still in progress.
    case storeEventNetworkTaskProgressUpdated = 9
    /// An HTTP call finished (success or error).
    case storeEventNetworkTaskCompleted = 10
    /// A generic text/control message.
    case message = 13
}

/// Why reading a packet failed: truncated buffer, or a body too large to encode.
enum PulsePacketParsingError: Error {
    case notEnoughData
    case unsupportedContentSize
}

/// One message after the header is stripped: type byte plus uncompressed body.
package struct PulsePacket {
    package let code: UInt8
    package let body: Data
}

/// Turns a type+body into bytes, and pulls one packet out of a receive buffer.
///
/// On the wire a packet is: 1 type byte, 4-byte big-endian length, then a compressed body.
package enum PulsePacketCodec {
    /// Build a packet: compress `body`, then prefix type and length.
    package static func encode(code: UInt8, body: Data) throws -> Data {
        guard body.count < UInt32.max else {
            throw PulsePacketParsingError.unsupportedContentSize
        }
        var data = Data()
        data.append(code)
        let compressedBody = try body.compressedLZFSE()
        data.append(Data(UInt32(compressedBody.count)))
        data.append(compressedBody)
        return data
    }

    /// Read the next packet from `buffer`. Second value is how many bytes that packet used.
    package static func decode(buffer: Data) throws -> (PulsePacket, Int) {
        let headerSize = 5
        guard buffer.count >= headerSize else {
            throw PulsePacketParsingError.notEnoughData
        }
        let code = buffer[buffer.startIndex]
        let contentSize = UInt32(bigEndianData: buffer.fromIndex(1, size: 4))
        let compressedLength = headerSize + Int(contentSize)
        guard buffer.count >= compressedLength else {
            throw PulsePacketParsingError.notEnoughData
        }
        let compressed = buffer.fromIndex(headerSize, size: Int(contentSize))
        let body = try compressed.decompressedLZFSE()
        return (PulsePacket(code: code, body: body), compressedLength)
    }
}

/// JSON body of the Mac's hello reply: protocol version string.
package struct PulseServerHello: Codable {
    package let version: String

    package init(version: String) {
        self.version = version
    }
}

/// Reads a "HTTP call finished" payload: size table, JSON event, then optional request and response bodies.
package enum PulseNetworkMessageCodec {
    private struct Manifest {
        let messageSize: UInt32
        let requestBodySize: UInt32
        let responseBodySize: UInt32
        static let size = 12
    }

    /// Decode a completed-task body into Pulse's `NetworkTaskCompleted` event, attaching the raw bodies.
    package static func decode(_ data: Data) throws -> LoggerStore.Event.NetworkTaskCompleted {
        guard data.count >= Manifest.size else {
            throw PulsePacketParsingError.notEnoughData
        }
        let messageSize = UInt32(bigEndianData: data.fromIndex(0, size: 4))
        let requestBodySize = UInt32(bigEndianData: data.fromIndex(4, size: 4))
        let responseBodySize = UInt32(bigEndianData: data.fromIndex(8, size: 4))
        let total = Manifest.size + Int(messageSize) + Int(requestBodySize) + Int(responseBodySize)
        guard data.count >= total else {
            throw PulsePacketParsingError.notEnoughData
        }
        let event = try JSONDecoder().decode(
            LoggerStore.Event.NetworkTaskCompleted.self,
            from: data.fromIndex(Manifest.size, size: Int(messageSize))
        )
        var requestBody: Data?
        if requestBodySize > 0 {
            requestBody = data.fromIndex(Manifest.size + Int(messageSize), size: Int(requestBodySize))
        }
        var responseBody: Data?
        if responseBodySize > 0 {
            responseBody = data.fromIndex(
                Manifest.size + Int(messageSize) + Int(requestBodySize),
                size: Int(responseBodySize)
            )
        }
        return LoggerStore.Event.NetworkTaskCompleted(
            taskId: event.taskId,
            taskType: event.taskType,
            createdAt: event.createdAt,
            originalRequest: event.originalRequest,
            currentRequest: event.currentRequest,
            response: event.response,
            error: event.error,
            requestBody: requestBody,
            responseBody: responseBody,
            metrics: event.metrics,
            label: event.label,
            taskDescription: event.taskDescription
        )
    }
}

// MARK: - Binary helpers (big-endian lengths, LZFSE compression)

extension Data {
    init(_ value: UInt32) {
        var content = value.bigEndian
        self.init(bytes: &content, count: MemoryLayout<UInt32>.size)
    }

    func fromIndex(_ from: Data.Index, size: Int) -> Data {
        self[(from + startIndex)..<(from + size + startIndex)]
    }
}

extension Data {
    func compressedLZFSE() throws -> Data {
        try (self as NSData).compressed(using: .lzfse) as Data
    }

    func decompressedLZFSE() throws -> Data {
        try (self as NSData).decompressed(using: .lzfse) as Data
    }
}

private extension UInt32 {
    init(bigEndianData data: Data) {
        var accumulator: UInt64 = 0
        for i in 0..<4 {
            let shift = (3 - i) * 8
            accumulator |= UInt64(data[data.startIndex + i]) << UInt64(shift)
        }
        self = UInt32(accumulator)
    }
}
