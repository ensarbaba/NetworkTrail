import SwiftUI
import NetworkTrailWire

/// The text and colors that the Mac app shows for a request.
extension CapturedRequest {
    /// Status code, "Failed" for a call that ended with an error and no response, "—" if finished with no code,
    /// or an ellipsis while in flight.
    var statusText: String {
        if let statusCode { return String(statusCode) }
        if error != nil { return "Failed" }
        return isComplete ? "—" : "…"
    }

    /// Red for errors and 5xx, orange for 4xx, green for 2xx; secondary for 3xx, unknown, and in flight.
    var statusColor: Color {
        if error != nil { return .red }
        switch statusCode {
        case .some(200..<300): return .green
        case .some(400..<500): return .orange
        case .some(500...): return .red
        default: return .secondary
        }
    }

    /// Milliseconds below one second (`556 ms`), seconds from one second (`1.1 s`), or an em dash if unknown.
    var durationText: String {
        guard let duration else { return "—" }
        return duration < 1
            ? String(format: "%.0f ms", duration * 1000)
            : String(format: "%.1f s", duration)
    }

    /// Response body size, for example `2 kB` or `380 bytes`, or an em dash while in flight or without a body.
    var sizeText: String {
        guard let responseBody else { return "—" }
        return Int64(responseBody.count).formatted(.byteCount(style: .file, spellsOutZero: false))
    }
}

/// "1 request" or "N requests".
func requestCountText(_ count: Int) -> String {
    count == 1 ? "1 request" : "\(count) requests"
}
