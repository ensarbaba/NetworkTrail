import Foundation
import ImageIO
@testable import NetworkTrailWire
import Testing

struct BodyImageTests {
    @Test(arguments: [
        (Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]), BodyImage.Format.png),
        (Data([0xFF, 0xD8, 0xFF, 0xE0]), .jpeg),
        (Data("GIF87a".utf8), .gif),
        (Data("GIF89a".utf8), .gif),
        (Data("RIFF\u{0}\u{0}\u{0}\u{0}WEBPVP8 ".utf8), .webp),
        (Data("\u{0}\u{0}\u{0}\u{18}ftypheic".utf8), .heic),
        (Data("\u{0}\u{0}\u{0}\u{18}ftyphevc".utf8), .heic),
    ])
    func formatComesFromTheFirstBytes(header: Data, format: BodyImage.Format) {
        #expect(BodyImage.Format(header: header) == format)
    }

    @Test(arguments: [
        Data("P1\n2 2\n1 0 0 1\n".utf8), // A text body that ImageIO reads as a PBM image.
        Data("RIFF\u{0}\u{0}\u{0}\u{0}WAVEfmt ".utf8),
        Data("\u{0}\u{0}\u{0}\u{18}ftypavif".utf8),
        Data("GIF8".utf8),
        Data([0x00, 0x01, 0x02]),
    ])
    func otherBytesAreNoImage(header: Data) {
        #expect(BodyImage.Format(header: header) == nil)
    }

    @Test(arguments: [
        ("public.png", BodyImage.Format.png),
        ("public.jpeg", .jpeg),
        ("com.compuserve.gif", .gif),
    ])
    func imageHasItsFormatAndPixelSize(type: String, format: BodyImage.Format) throws {
        let data = try makeImage(type: type, width: 3, height: 2)
        let image = try #require(BodyImage(data: data))

        #expect(image.format == format)
        #expect(image.pixelWidth == 3)
        #expect(image.pixelHeight == 2)
        #expect(BodyContent(data: data) == .image(image))
    }

    @Test func onlyTheFirstBytesOfAnImageAreBinary() {
        let header = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

        #expect(BodyImage(data: header) == nil)
        #expect(BodyContent(data: header) == .binary(byteCount: 8))
    }

    /// A one-color image, encoded by ImageIO.
    private func makeImage(type: String, width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, type as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
