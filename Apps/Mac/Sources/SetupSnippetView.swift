import SwiftUI

/// Sheet with the snippet and the steps to add it to an iOS app.
/// The Setup Snippet button in the bottom bar and File > Show Setup Snippet… open it.
struct SetupSnippetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SetupSnippetContent(title: "Setup Snippet", titleFont: .headline)
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
/// in a centered column, with the title "Connect your first app".
struct FirstRunView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SetupSnippetContent(title: "Connect your first app", titleFont: .title2.weight(.semibold))
            CopySnippetButton()
        }
        // As wide as the longest snippet line, so that the column can be centered.
        .fixedSize(horizontal: true, vertical: false)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The title, what NetworkTrail does, the three steps, the snippet, and a warning when NetworkTrail is not
/// in the Applications folder.
private struct SetupSnippetContent: View {
    let title: String
    let titleFont: Font

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(titleFont)
            Text("NetworkTrail shows the URLSession traffic of Debug builds in the iOS Simulator.")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Copy the snippet.")
                Text("2. Paste it once into your app's launch code, for example App.init.")
                Text("3. Run a Debug build in the Simulator. The app shows in the sidebar.")
            }
            // Code keeps its lines. The content takes the width of the longest line.
            Text(SimulatorSnippet.source)
                .font(.system(.callout, design: .monospaced))
                .fixedSize()
                .textSelection(.enabled)
                .padding(10)
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
