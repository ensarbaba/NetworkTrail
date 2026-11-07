import SwiftUI

/// Sheet with the snippet and the steps to add it to an iOS app.
/// The Setup Snippet button in the bottom bar and File > Show Setup Snippet… open it.
struct SetupSnippetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SetupSnippetContent(title: "Setup Snippet", style: .sheet, codeScrolls: false)
            HStack {
                Spacer()
                CopySnippetButton()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .onExitCommand {
            dismiss()
        }
    }
}

/// The main area until the first app connects in this run: the content of the Setup Snippet sheet
/// with larger text, in a centered column, with the title "Connect your first app".
struct FirstRunView: View {
    var body: some View {
        // The column is as wide as the longest snippet line, so that it can be centered. When the pane is
        // narrower, the column fills the pane and the code box scrolls sideways.
        ViewThatFits(in: .horizontal) {
            column(codeScrolls: false)
                .fixedSize(horizontal: true, vertical: false)
            column(codeScrolls: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func column(codeScrolls: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SetupSnippetContent(title: "Connect your first app", style: .firstRun, codeScrolls: codeScrolls)
            CopySnippetButton()
                .controlSize(.large)
        }
    }
}

/// The text sizes of `SetupSnippetContent`: compact in the sheet, larger on the first-run screen.
private struct SetupSnippetStyle {
    let titleFont: Font
    let textFont: Font
    let codeFont: Font

    static let sheet = SetupSnippetStyle(
        titleFont: .headline,
        textFont: .body,
        codeFont: .system(.callout, design: .monospaced)
    )
    static let firstRun = SetupSnippetStyle(
        titleFont: .largeTitle.weight(.semibold),
        textFont: .title3,
        codeFont: .system(.body, design: .monospaced)
    )
}

/// The title, what NetworkTrail does, the three steps, the snippet, and a warning when NetworkTrail is not
/// in the Applications folder.
private struct SetupSnippetContent: View {
    let title: String
    let style: SetupSnippetStyle
    /// True: the code box scrolls sideways when it is narrower than the snippet. False: the box is never
    /// narrower than the longest snippet line.
    let codeScrolls: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(style.titleFont)
            Text("NetworkTrail shows the URLSession traffic of Debug builds in the iOS Simulator.")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Copy the snippet.")
                Text("2. Paste it once into your app's launch code, for example App.init.")
                Text("3. Run a Debug build in the Simulator. The app shows in the sidebar.")
            }
            Group {
                if codeScrolls {
                    ScrollView(.horizontal) {
                        snippet
                    }
                } else {
                    snippet
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: .rect(cornerRadius: 6))
            // The snippet loads the framework from this fixed path, so another copy of the app does not help.
            if !FileManager.default.fileExists(atPath: SimulatorSnippet.frameworkPath) {
                Label {
                    Text("Move NetworkTrail to the Applications folder. The snippet loads it from there.")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.multicolor)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.yellow.opacity(0.15), in: .rect(cornerRadius: 6))
            }
        }
        .font(style.textFont)
    }

    /// The snippet in its own lines: code does not wrap.
    private var snippet: some View {
        Text(SimulatorSnippet.source)
            .font(style.codeFont)
            .fixedSize()
            .textSelection(.enabled)
            .padding(10)
    }
}

/// Copies the snippet and shows "Copied" for 2 seconds.
private struct CopySnippetButton: View {
    @State private var isCopied = false

    var body: some View {
        Button(isCopied ? "Copied" : "Copy Snippet") {
            Pasteboard.copy(SimulatorSnippet.source)
            isCopied = true
        }
        .task(id: isCopied) {
            guard isCopied else { return }
            try? await Task.sleep(for: .seconds(2))
            isCopied = false
        }
    }
}
