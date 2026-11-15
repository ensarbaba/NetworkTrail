import Foundation
import NetworkTrailWire

/// Builds a `curl` command the user can paste in Terminal from one captured HTTP request.
///
/// Uses method, URL, request headers, and body. A binary body is base64 text that the shell decodes.
enum CurlBuilder {
    /// One-line `curl -X` with quoted URL, `-H` headers, and the body.
    static func make(from request: CapturedRequest) -> String {
        var parts = ["curl -X \(shellEscape(request.method))"]
        parts.append(shellEscape(request.url))

        for key in request.requestHeaders.keys.sorted() {
            let value = request.requestHeaders[key] ?? ""
            parts.append("-H \(shellEscape("\(key): \(value)"))")
        }

        if let body = request.requestBody, !body.isEmpty {
            if let string = String(data: body, encoding: .utf8) {
                // Not `-d`: it reads a file when the body starts with "@".
                parts.append("--data-raw \(shellEscape(string))")
            } else {
                // The shell decodes the bytes, and curl reads them as a file (zsh and bash).
                parts.append("--data-binary @<(echo '\(body.base64EncodedString())' | base64 --decode)")
            }
        }

        return parts.joined(separator: " ")
    }

    /// Wrap in single quotes so spaces and most shell metacharacters survive paste.
    private static func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
