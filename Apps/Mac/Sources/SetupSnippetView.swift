import SwiftUI

/// Sheet with the snippet and the steps to add it to an iOS app.
/// The Setup Snippet button in the sidebar and File > Show Setup Snippet… open it.
struct SetupSnippetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Setup Snippet")
                .font(.headline)
            Text("NetworkTrail shows the URLSession traffic of Debug builds in the iOS Simulator.")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Copy the snippet.")
                Text("2. Paste it once into your app's launch code, for example App.init.")
                Text("3. Run a Debug build in the Simulator. The app shows in the sidebar.")
            }
            // Code keeps its lines. The sheet takes the width of the longest line.
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
            HStack {
                Spacer()
                Button(isCopied ? "Copied" : "Copy Snippet") {
                    Pasteboard.copy(SimulatorSnippet.source)
                    isCopied = true
                }
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
        .task(id: isCopied) {
            guard isCopied else { return }
            try? await Task.sleep(for: .seconds(2))
            isCopied = false
        }
    }
}
