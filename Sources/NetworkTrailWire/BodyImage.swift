import Foundation
import ImageIO

/// An image body: its format and its size in pixels.
public struct BodyImage: Equatable, Sendable {
    /// The formats that the inspector shows. The raw value is the name that it shows.
    public enum Format: String, Equatable, Sendable {
        case png = "PNG"
        case jpeg = "JPEG"
        case gif = "GIF"
        case heic = "HEIC"
        case webp = "WebP"

        /// The format from the first bytes of a file ("magic bytes"), or nil.
        ///
        /// Only these bytes, not ImageIO: ImageIO also reads formats that start like plain text,
        /// for example PBM ("P1"), so it could take a text body for an image.
        init?(header data: Data) {
            let bytes = [UInt8](data.prefix(12))
            func has(_ ascii: String, at offset: Int) -> Bool {
                let expected = [UInt8](ascii.utf8)
                return bytes.count >= offset + expected.count && Array(bytes[offset..<offset + expected.count]) == expected
            }
            if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
                self = .png
            } else if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
                self = .jpeg
            } else if has("GIF87a", at: 0) || has("GIF89a", at: 0) {
                self = .gif
            } else if has("RIFF", at: 0), has("WEBP", at: 8) {
                self = .webp
            } else if has("ftyp", at: 4), ["heic", "heix", "hevc", "hevx"].contains(where: { has($0, at: 8) }) {
                self = .heic
            } else {
                return nil
            }
        }
    }

    public let format: Format
    public let pixelWidth: Int
    public let pixelHeight: Int

    /// Nil if `data` does not start like one of the formats, or if ImageIO cannot read its size.
    public init?(data: Data) {
        guard let format = Format(header: data),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        self.format = format
        pixelWidth = width
        pixelHeight = height
    }
}
