import AppKit
import SwiftUI
import NetworkTrailWire

/// "Body · JSON · 412 bytes" with Pretty and Raw (JSON only) and Copy, then the body text.
/// "No body" without a body; only the title for a binary body.
///
/// The kind comes from the bytes (`BodyContent`), not from `Content-Type`. The parsing runs off the main thread.
struct BodySection: View {
    let data: Data?
    /// The last choice for JSON bodies. It stays for the next request and after NetworkTrail starts again.
    @AppStorage("inspector.bodyFormat") private var format = BodyFormat.pretty
    /// Nil while the body is parsed.
    @State private var content: BodyContent?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Body")
                    .font(.headline)
                if let summary {
                    Text("· " + summary)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if case .json = content {
                    Picker("Format", selection: $format) {
                        Text("Pretty").tag(BodyFormat.pretty)
                        Text("Raw").tag(BodyFormat.raw)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                if let shownText {
                    Button("Copy") { Pasteboard.copy(shownText) }
                }
            }
            .controlSize(.small)
            switch content {
            case .empty:
                Text("No body")
                    .foregroundStyle(.secondary)
            case .json(let json, let raw):
                BodyTextView(content: format == .pretty ? .json(json) : .plain(raw))
            case .text(let text):
                BodyTextView(content: .plain(text))
            case .binary, nil:
                EmptyView()
            }
        }
        .task(id: data) {
            content = nil
            let data = data
            let parsed = await Task.detached(priority: .userInitiated) { BodyContent(data: data) }.value
            // A newer body may have started its own parsing.
            guard !Task.isCancelled else { return }
            content = parsed
        }
    }

    /// "JSON · 412 bytes", "Text · 23 bytes", or "Binary · 2 kB". Nil without a body and while parsing.
    private var summary: String? {
        guard let data, let content else { return nil }
        switch content {
        case .empty: return nil
        case .json: return "JSON · " + byteCountText(data.count)
        case .text: return "Text · " + byteCountText(data.count)
        case .binary: return "Binary · " + byteCountText(data.count)
        }
    }

    /// The text that shows, for Copy. Nil without a body, for a binary body, and while parsing.
    private var shownText: String? {
        switch content {
        case .json(let json, let raw): format == .pretty ? json.text : raw
        case .text(let text): text
        case .empty, .binary, nil: nil
        }
    }
}

/// The JSON formats. The raw value is saved in `UserDefaults`.
private enum BodyFormat: String {
    case pretty
    case raw
}

/// Selectable body text that does not scroll: it is as high as its text, and the inspector scrolls it.
/// AppKit, because a SwiftUI `Text` is slow with long bodies.
private struct BodyTextView: NSViewRepresentable {
    enum Content: Equatable {
        /// Syntax colors: keys in the text color, strings red, numbers blue, `true`, `false`, and `null` pink,
        /// punctuation gray.
        case json(PrettyJSON)
        case plain(String)
    }

    let content: Content

    func makeNSView(context: Context) -> FittingTextView {
        // TextKit 1: `layoutManager` gives the height of the text.
        let textView = FittingTextView(usingTextLayoutManager: false)
        textView.isEditable = false
        textView.isRichText = false
        textView.drawsBackground = false
        textView.isVerticallyResizable = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        return textView
    }

    func updateNSView(_ textView: FittingTextView, context: Context) {
        guard context.coordinator.shownContent != content else { return }
        context.coordinator.shownContent = content
        textView.textStorage?.setAttributedString(attributedText)
        textView.invalidateIntrinsicContentSize()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// The content in the text view, so that an update with the same content does not set the text again.
    final class Coordinator {
        var shownContent: Content?
    }

    private var attributedText: NSAttributedString {
        let font = NSFont.monospacedSystemFont(
            ofSize: NSFont.preferredFont(forTextStyle: .callout).pointSize,
            weight: .regular
        )
        switch content {
        case .plain(let text):
            return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        case .json(let json):
            let text = NSMutableAttributedString(
                string: json.text,
                attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
            )
            for token in json.tokens {
                text.addAttribute(.foregroundColor, value: Self.color(for: token.kind), range: NSRange(token.range))
            }
            return text
        }
    }

    private static func color(for kind: PrettyJSON.TokenKind) -> NSColor {
        switch kind {
        case .key: .labelColor
        case .string: .systemRed
        case .number: .systemBlue
        case .literal: .systemPink
        }
    }
}

/// A text view as high as its text at its frame width. SwiftUI sets the width.
///
/// Not `sizeThatFits`: SwiftUI calls it with many trial widths (0, infinity, other column widths),
/// and each width lays out the full text again.
private final class FittingTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
        // Before SwiftUI sets the width, a layout would put each character on its own line.
        guard frame.width > 0, let textContainer, let layoutManager else {
            return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
        }
        layoutManager.ensureLayout(for: textContainer)
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(layoutManager.usedRect(for: textContainer).height))
    }

    override func setFrameSize(_ newSize: NSSize) {
        let widthChanged = newSize.width != frame.width
        super.setFrameSize(newSize)
        if widthChanged {
            invalidateIntrinsicContentSize()
        }
    }
}
