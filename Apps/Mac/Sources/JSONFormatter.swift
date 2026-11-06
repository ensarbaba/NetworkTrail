import Foundation

/// Turns a request or response body into text for the inspector.
///
/// Tries JSON first (indented, keys sorted). If that fails, shows UTF-8 text.
/// If that fails too, shows a byte-count placeholder.
enum JSONFormatter {
    /// Pretty JSON, plain text, or a binary placeholder for a body that is not empty.
    static func prettyString(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: pretty, encoding: .utf8) {
            return string
        }
        if let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "<\(data.count) bytes binary>"
    }
}
