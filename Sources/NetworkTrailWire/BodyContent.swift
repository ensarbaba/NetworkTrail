import Foundation

/// A request or response body, sorted by its content into the kinds that the inspector shows.
///
/// The `Content-Type` header is not used: a JSON body sent as `text/plain` is JSON here too.
public enum BodyContent: Equatable, Sendable {
    /// No body, or a body of 0 bytes.
    case empty
    /// A JSON object or array: indented, and as sent.
    case json(PrettyJSON, raw: String)
    /// UTF-8 text that is not a JSON object or array.
    case text(String)
    /// Bytes that are not UTF-8 text.
    case binary(byteCount: Int)

    /// Parses JSON bodies. For a large body, call it off the main thread.
    public init(data: Data?) {
        guard let data, !data.isEmpty else {
            self = .empty
            return
        }
        guard let text = String(data: data, encoding: .utf8) else {
            self = .binary(byteCount: data.count)
            return
        }
        if let json = PrettyJSON(data: data) {
            self = .json(json, raw: text)
        } else {
            self = .text(text)
        }
    }
}

/// A JSON object or array as indented text, with the ranges of keys and values for syntax colors.
///
/// Unlike `JSONSerialization`, it keeps the key order and the number text of the server, for example `1.50`.
public struct PrettyJSON: Equatable, Sendable {
    public enum TokenKind: Equatable, Sendable {
        case key
        case string
        case number
        /// `true`, `false`, or `null`.
        case literal
    }

    public struct Token: Equatable, Sendable {
        public let kind: TokenKind
        /// The range in `text`, in UTF-16 code units (the units of `NSRange`).
        public let range: Range<Int>
    }

    /// Two spaces for each level. Empty objects and arrays stay on one line: `{}`, `[]`.
    public let text: String
    /// Keys and values. The text between them is punctuation and white space.
    public let tokens: [Token]

    /// Nil if `data` is not a JSON object or array in UTF-8.
    public init?(data: Data) {
        // `JSONSerialization` checks the syntax. The loop below only changes the white space,
        // and stops at a byte that UTF-8 JSON cannot have there (for example the 0 bytes of UTF-16).
        guard (try? JSONSerialization.jsonObject(with: data)) != nil else { return nil }
        let bytes = [UInt8](data)
        var output = Output()
        // One value for each open container: true for an object, false for an array.
        var openContainers: [Bool] = []
        // True when the next string is a key.
        var expectsKey = false
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            switch byte {
            case _ where Self.isWhiteSpace(byte):
                index += 1
            case .openBrace, .openBracket:
                let close: UInt8 = byte == .openBrace ? .closeBrace : .closeBracket
                var next = index + 1
                while next < bytes.count, Self.isWhiteSpace(bytes[next]) { next += 1 }
                if next < bytes.count, bytes[next] == close {
                    output.append([byte, close])
                    index = next + 1
                } else {
                    output.append([byte])
                    openContainers.append(byte == .openBrace)
                    expectsKey = byte == .openBrace
                    output.appendNewLine(depth: openContainers.count)
                    index += 1
                }
            case .closeBrace, .closeBracket:
                openContainers.removeLast()
                output.appendNewLine(depth: openContainers.count)
                output.append([byte])
                index += 1
            case .comma:
                output.append([byte])
                output.appendNewLine(depth: openContainers.count)
                expectsKey = openContainers.last == true
                index += 1
            case .colon:
                output.append([byte, .space])
                expectsKey = false
                index += 1
            case .quote:
                var end = index + 1
                while end < bytes.count, bytes[end] != .quote {
                    end += bytes[end] == .backslash ? 2 : 1
                }
                guard end < bytes.count else { return nil }
                output.append(bytes[index...end], as: expectsKey ? .key : .string)
                index = end + 1
            case .minus, UInt8(ascii: "0")...UInt8(ascii: "9"):
                var end = index
                while end < bytes.count, Self.isNumberByte(bytes[end]) { end += 1 }
                output.append(bytes[index..<end], as: .number)
                index = end
            case UInt8(ascii: "a")...UInt8(ascii: "z"):
                var end = index
                while end < bytes.count, (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(bytes[end]) { end += 1 }
                output.append(bytes[index..<end], as: .literal)
                index = end
            default:
                return nil
            }
        }
        text = String(decoding: output.bytes, as: UTF8.self)
        tokens = output.tokens
    }

    private static func isWhiteSpace(_ byte: UInt8) -> Bool {
        byte == .space || byte == UInt8(ascii: "\t") || byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\r")
    }

    private static func isNumberByte(_ byte: UInt8) -> Bool {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
            || byte == .minus || byte == UInt8(ascii: "+") || byte == UInt8(ascii: ".")
            || byte == UInt8(ascii: "e") || byte == UInt8(ascii: "E")
    }

    /// The UTF-8 output, its length in UTF-16 code units, and the tokens.
    private struct Output {
        var bytes: [UInt8] = []
        var utf16Count = 0
        var tokens: [Token] = []

        /// Appends ASCII punctuation.
        mutating func append(_ ascii: [UInt8]) {
            bytes += ascii
            utf16Count += ascii.count
        }

        mutating func appendNewLine(depth: Int) {
            append([UInt8(ascii: "\n")] + Array(repeating: .space, count: depth * 2))
        }

        /// Appends a key or value as sent.
        mutating func append(_ token: ArraySlice<UInt8>, as kind: TokenKind) {
            let start = utf16Count
            // One UTF-16 unit for each character, two for a character of four UTF-8 bytes (lead byte 0xF0 or more).
            // Continuation bytes (0b10xxxxxx) do not start a character.
            for byte in token where byte & 0xC0 != 0x80 {
                utf16Count += byte >= 0xF0 ? 2 : 1
            }
            bytes += token
            tokens.append(Token(kind: kind, range: start..<utf16Count))
        }
    }
}

private extension UInt8 {
    static let space = UInt8(ascii: " ")
    static let quote = UInt8(ascii: "\"")
    static let backslash = UInt8(ascii: "\\")
    static let comma = UInt8(ascii: ",")
    static let colon = UInt8(ascii: ":")
    static let minus = UInt8(ascii: "-")
    static let openBrace = UInt8(ascii: "{")
    static let closeBrace = UInt8(ascii: "}")
    static let openBracket = UInt8(ascii: "[")
    static let closeBracket = UInt8(ascii: "]")
}
