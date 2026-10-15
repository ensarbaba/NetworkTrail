import Foundation
import NetworkTrailProtocol
import Pulse
import Testing

struct PulseNetworkMessageCodecTests {
    @Test func roundTripKeepsRequestResponseAndBodies() throws {
        let event = makeEvent(
            requestBody: Data(#"{"hello":"NetworkTrail"}"#.utf8),
            responseBody: Data(#"{"ok":true}"#.utf8)
        )

        let decoded = try PulseNetworkMessageCodec.decode(PulseNetworkMessageCodec.encode(event))

        #expect(decoded.taskId == event.taskId)
        #expect(decoded.createdAt == event.createdAt)
        #expect(decoded.originalRequest.httpMethod == "POST")
        #expect(decoded.originalRequest.url == event.originalRequest.url)
        #expect(decoded.originalRequest.headers?["Content-Type"] == "application/json")
        #expect(decoded.response?.statusCode == 201)
        #expect(decoded.requestBody == event.requestBody)
        #expect(decoded.responseBody == event.responseBody)
    }

    @Test func roundTripWithoutBodiesDecodesNilBodies() throws {
        let event = makeEvent(requestBody: nil, responseBody: nil)

        let decoded = try PulseNetworkMessageCodec.decode(PulseNetworkMessageCodec.encode(event))

        #expect(decoded.requestBody == nil)
        #expect(decoded.responseBody == nil)
    }

    @Test func roundTripThroughPacketFraming() throws {
        let event = makeEvent(requestBody: nil, responseBody: Data("pong".utf8))
        let packet = try PulsePacketCodec.encode(
            code: PulsePacketCode.storeEventNetworkTaskCompleted.rawValue,
            body: PulseNetworkMessageCodec.encode(event)
        )

        let (decodedPacket, size) = try PulsePacketCodec.decode(buffer: packet)
        let decoded = try PulseNetworkMessageCodec.decode(decodedPacket.body)

        #expect(size == packet.count)
        #expect(decodedPacket.code == PulsePacketCode.storeEventNetworkTaskCompleted.rawValue)
        #expect(decoded.responseBody == Data("pong".utf8))
    }

    private func makeEvent(requestBody: Data?, responseBody: Data?) -> LoggerStore.Event.NetworkTaskCompleted {
        let url = URL(string: "https://example.com/post")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let response = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
        return LoggerStore.Event.NetworkTaskCompleted(
            taskId: UUID(),
            taskType: .dataTask,
            createdAt: Date(timeIntervalSince1970: 1_000),
            originalRequest: NetworkLogger.Request(request),
            currentRequest: NetworkLogger.Request(request),
            response: NetworkLogger.Response(response),
            error: nil,
            requestBody: requestBody,
            responseBody: responseBody,
            metrics: nil,
            label: nil,
            taskDescription: nil
        )
    }
}
