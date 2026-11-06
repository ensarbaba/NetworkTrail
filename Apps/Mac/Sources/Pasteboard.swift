import AppKit
import UniformTypeIdentifiers

/// Writes to the general pasteboard and replaces what was there.
enum Pasteboard {
    /// Plain text.
    static func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    /// The image bytes as sent, and TIFF for apps that cannot read the type (for example WebP).
    static func copyImage(_ data: Data, type: UTType) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data, forType: NSPasteboard.PasteboardType(type.identifier))
        if let tiff = NSImage(data: data)?.tiffRepresentation {
            NSPasteboard.general.setData(tiff, forType: .tiff)
        }
    }
}
