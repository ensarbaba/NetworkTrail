import Foundation
import NetworkTrailWire

/// Builds a `curl` command the user can paste in Terminal from one captured HTTP request.
///
/// Uses method, URL, request headers, and UTF-8 body. Binary bodies are not inlined;
/// the string tells you to copy that body another way.
enum CurlBuilder {
    /// One-line `curl -X …` with quoted URL, `-H` headers, and `-d` body when it is text.
    static func make(from request: CapturedRequest) -> String {
        var parts = ["curl -X \(shellEscape(request.method))"]
        parts.append(shellEscape(request.url))

        for key in request.requestHeaders.keys.sorted() {
            let value = request.requestHeaders[key] ?? ""
            parts.append("-H \(shellEscape("\(key): \(value)"))")
        }

        if let body = request.requestBody, !body.isEmpty {
            if let string = String(data: body, encoding: .utf8) {
                parts.append("-d \(shellEscape(string))")
            } else {
                parts.append("--data-binary @<(base64 decode omitted — copy body separately)")
            }
        }

        return parts.joined(separator: " ")
    }

    /// Wrap in single quotes so spaces and most shell metacharacters survive paste.
    private static func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
