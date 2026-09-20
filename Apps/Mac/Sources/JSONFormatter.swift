import Foundation

/// Turns a request or response body into text for the Mac detail pane.
///
/// Tries JSON first (indented, keys sorted). If that fails, shows UTF-8 text.
/// If that fails too, shows a byte-count placeholder. `wrap` false flattens newlines.
enum JSONFormatter {
    /// Pretty JSON, plain text, empty-body, or binary placeholder.
    static func prettyString(from data: Data?, wrap: Bool) -> String {
        guard let data, !data.isEmpty else { return "Empty body" }
        if let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: pretty, encoding: .utf8) {
            return wrap ? string : string.replacingOccurrences(of: "\n", with: "")
        }
        if let string = String(data: data, encoding: .utf8) {
            return wrap ? string : string.replacingOccurrences(of: "\n", with: " ")
        }
        return "<\(data.count) bytes binary>"
    }
}
