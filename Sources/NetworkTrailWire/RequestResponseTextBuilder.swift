import Foundation

/// Builds the text of Copy Request and Response: one call as HTTP message text in one code block,
/// to share in a chat, an issue, or an email.
///
/// Two comment lines (app and device; start and duration), the request line `METHOD URL` with the request
/// headers and body, then the status line `HTTP 200` with the response headers and body. A call without
/// a response has a comment line with the error in place of the response. Nothing is redacted: headers and
/// bodies are as sent, also tokens and cookies. Numbers have a fixed format, not the format of the Mac locale.
public enum RequestResponseTextBuilder {
    /// The largest text of one body, in UTF-8 bytes. A longer body is cut, and a comment line says so.
    /// Two bodies at the limit stay below the 40,000 characters that Slack keeps of a message.
    static let bodyLimit = 16_384

    /// - Parameters:
    ///   - client: The app that sent the request. Nil leaves out the app line.
    ///   - timeZone: The time zone of the start time.
    public static func make(from request: CapturedRequest, client: CapturedClient?, timeZone: TimeZone = .current) -> String {
        var parts = [
            summary(of: request, client: client, timeZone: timeZone),
            message(firstLine: "\(request.method) \(request.url)", headers: request.requestHeaders, body: request.requestBody),
        ]
        if !request.isComplete {
            parts.append("# Waiting for response.")
        } else if let statusCode = request.statusCode {
            // The HTTP version is not captured, so the status line has no version.
            parts.append(message(firstLine: "HTTP \(statusCode)", headers: request.responseHeaders, body: request.responseBody))
        } else if request.error == nil {
            parts.append("# No response.")
        }
        if let error = request.error {
            // In place of the response, or after it when the call also has a status.
            let label = request.statusCode == nil ? "No response" : "Error"
            parts.append("# \(label): \(error.title) (\(error.domain) \(error.code))\n\(error.debugDescription)")
        }
        return codeBlock(parts.joined(separator: "\n\n"))
    }

    /// "# Demo · iPhone 18 Pro, 27.0" (when the app is known) and "# <start> · <duration>".
    private static func summary(of request: CapturedRequest, client: CapturedClient?, timeZone: TimeZone) -> String {
        var lines: [String] = []
        if let client {
            lines.append("# \(client.appName) · \(client.deviceName), \(client.systemVersion)")
        }
        let startStyle = Date.ISO8601FormatStyle(timeZoneSeparator: .colon, includingFractionalSeconds: true, timeZone: timeZone)
        var timing = request.createdAt.formatted(startStyle)
        if let duration = request.duration {
            // Whole milliseconds, without separators: "420 ms".
            timing += " · " + String(format: "%.0f ms", duration * 1000)
        }
        lines.append("# " + timing)
        return lines.joined(separator: "\n")
    }

    /// The first line, one "name: value" line for each header (sorted by name without regard to case),
    /// then an empty line and the body, when there is a body.
    private static func message(firstLine: String, headers: [String: String], body: Data?) -> String {
        let headerLines = headers
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { "\($0.key): \($0.value)" }
        let head = ([firstLine] + headerLines).joined(separator: "\n")
        guard let bodyText = bodyText(body) else { return head }
        return head + "\n\n" + bodyText
    }

    /// Indented JSON with the key order of the server, or the text. Images and other binary data
    /// are not included: one comment line gives the kind and the size. Nil when there is no body.
    private static func bodyText(_ data: Data?) -> String? {
        let size = "\(data?.count ?? 0) bytes"
        switch BodyContent(data: data) {
        case .empty:
            return nil
        case .json(let pretty, raw: _):
            return cut(pretty.text)
        case .text(let text):
            return cut(text)
        case .image(let image):
            return "# \(image.format.rawValue) image, \(image.pixelWidth) × \(image.pixelHeight) px, \(size). Not included."
        case .binary:
            return "# Binary data, \(size). Not included."
        }
    }

    /// The text cut at `bodyLimit` bytes, with a comment line after it when it is cut.
    private static func cut(_ text: String) -> String {
        guard text.utf8.count > bodyLimit else { return text }
        // Keep whole characters, so that a multi-byte character is not split.
        var byteCount = 0
        var end = text.startIndex
        for character in text {
            guard byteCount + character.utf8.count <= bodyLimit else { break }
            byteCount += character.utf8.count
            end = text.index(after: end)
        }
        return String(text[..<end]) + "\n# Only the first \(byteCount) of \(text.utf8.count) bytes of this body are shown."
    }

    /// A fenced code block without a language: Slack shows a language word as text. The fence is longer
    /// than the longest run of backticks in the text, so that a body with ``` in it does not end the block.
    private static func codeBlock(_ text: String) -> String {
        var longestRun = 0
        var run = 0
        for character in text {
            run = character == "`" ? run + 1 : 0
            longestRun = max(longestRun, run)
        }
        let fence = String(repeating: "`", count: max(3, longestRun + 1))
        return "\(fence)\n\(text)\n\(fence)"
    }
}
