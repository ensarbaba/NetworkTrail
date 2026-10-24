import SwiftUI
import NetworkTrailWire

/// Right-hand pane: one selected HTTP call — URL, headers, pretty body, copy, cURL.
///
/// Reads `store.selectedRequest`. Bodies go through `JSONFormatter`. cURL uses `CurlBuilder`.
/// Our own SwiftUI; not Pulse’s console UI.
struct RequestDetailView: View {
    @Environment(SessionStore.self) private var store
    @State private var wrapLines = true
    @State private var selectedBodyTab = 0

    var body: some View {
        if let request = store.selectedRequest {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(for: request)
                    Picker("Body", selection: $selectedBodyTab) {
                        Text("Request").tag(0)
                        Text("Response").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)

                    Toggle("Wrap lines", isOn: $wrapLines)

                    bodySection(
                        title: selectedBodyTab == 0 ? "Request body" : "Response body",
                        data: selectedBodyTab == 0 ? request.requestBody : request.responseBody
                    )

                    headerSection(title: "Request headers", headers: request.requestHeaders)
                    headerSection(title: "Response headers", headers: request.responseHeaders)

                    if let error = request.errorDescription {
                        GroupBox("Error") {
                            Text(error)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView(
                "No request selected",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Choose a row in the request list to inspect headers and bodies.")
            )
        }
    }

    /// Method + URL, plus copy URL and copy as cURL.
    @ViewBuilder
    private func header(for request: CapturedRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(request.method) \(request.url)")
                .font(.headline)
                .textSelection(.enabled)
            HStack {
                Button("Copy URL") { Pasteboard.copy(request.url) }
                Button("Copy as cURL") { Pasteboard.copy(CurlBuilder.make(from: request)) }
            }
        }
    }

    /// Sorted header names and values, or “None”.
    @ViewBuilder
    private func headerSection(title: String, headers: [String: String]) -> some View {
        GroupBox(title) {
            if headers.isEmpty {
                Text("None").foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(headers.keys.sorted(), id: \.self) { key in
                        HStack(alignment: .top) {
                            Text(key).fontWeight(.semibold)
                            Text(headers[key] ?? "")
                                .textSelection(.enabled)
                        }
                        .font(.caption.monospaced())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Pretty-printed body via `JSONFormatter`, with a copy button.
    @ViewBuilder
    private func bodySection(title: String, data: Data?) -> some View {
        GroupBox(title) {
            let text = JSONFormatter.prettyString(from: data, wrap: wrapLines)
            HStack {
                Spacer()
                Button("Copy") { Pasteboard.copy(text) }
            }
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
