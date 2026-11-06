import Foundation
@testable import NetworkTrailWire
import Testing

struct BodyContentTests {
    @Test func prettyJSONKeepsKeyOrderAndNumberText() throws {
        let json = try #require(PrettyJSON(data: Data(#"{"b":1.50,"a":[true,null,"x"],"c":-2E+3}"#.utf8)))

        #expect(json.text == """
            {
              "b": 1.50,
              "a": [
                true,
                null,
                "x"
              ],
              "c": -2E+3
            }
            """)
    }

    @Test func emptyObjectsAndArraysStayOnOneLine() throws {
        let json = try #require(PrettyJSON(data: Data(#"[{ }, {"a":[ ]}]"#.utf8)))

        #expect(json.text == """
            [
              {},
              {
                "a": []
              }
            ]
            """)
    }

    @Test func stringsStayAsSent() throws {
        // Punctuation, escaped quotes, and spaces inside a string are not formatted.
        let json = try #require(PrettyJSON(data: Data(#"["a, b: {c} \"d\"  e\\"]"#.utf8)))

        #expect(json.text == #"""
            [
              "a, b: {c} \"d\"  e\\"
            ]
            """#)
    }

    @Test func tokensMarkKeysAndValuesInUTF16Units() throws {
        // "é" is one UTF-16 unit and "😀" is two, so the ranges after them count UTF-16 units, not bytes.
        let json = try #require(PrettyJSON(data: Data(#"{"é😀":["x",1,false],"n":{"k":null}}"#.utf8)))
        let text = json.text as NSString

        #expect(json.tokens.map { "\($0.kind) \(text.substring(with: NSRange($0.range)))" } == [
            #"key "é😀""#,
            #"string "x""#,
            "number 1",
            "literal false",
            #"key "n""#,
            #"key "k""#,
            "literal null",
        ])
    }

    @Test(arguments: [
        Data("123".utf8),
        Data(#""text""#.utf8),
        Data(#"{"a":}"#.utf8),
        #"{"a":1}"#.data(using: .utf16LittleEndian)!,
    ])
    func onlyAUTF8ObjectOrArrayIsJSON(data: Data) {
        #expect(PrettyJSON(data: data) == nil)
    }

    @Test func contentKindComesFromTheBytes() throws {
        let raw = #"{"a" : 1}"#

        #expect(BodyContent(data: nil) == .empty)
        #expect(BodyContent(data: Data()) == .empty)
        #expect(BodyContent(data: Data([0x89, 0x50, 0x4E, 0x47])) == .binary(byteCount: 4))
        #expect(BodyContent(data: Data("a=1&b=two".utf8)) == .text("a=1&b=two"))
        #expect(BodyContent(data: Data(raw.utf8)) == .json(try #require(PrettyJSON(data: Data(raw.utf8))), raw: raw))
    }
}
