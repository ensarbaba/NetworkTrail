import SwiftUI
import NetworkTrailWire

/// The inspector on the right: the selected request (`SessionStore.selectedRequest`), or "No request selected".
///
/// A fixed header on top. Below it, the error banner (only for a call without a response)
/// and the Request and Response tabs. Each tab shows its sections in this order: query parameters
/// (Request only), headers, body.
struct RequestInspector: View {
    @Environment(SessionStore.self) private var store
    /// The last tab that the user chose. It stays for the next request and after NetworkTrail starts again.
    /// Response at the first start: it is the tab that a developer usually needs.
    @AppStorage("inspector.tab") private var tab = InspectorTab.response

    var body: some View {
        if let request = store.selectedRequest {
            VStack(alignment: .leading, spacing: 0) {
                InspectorHeader(request: request, appName: store.client(id: request.clientID)?.appName)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let error = request.error, request.statusCode == nil {
                            ErrorBanner(error: error)
                        }
                        Picker("Tab", selection: $tab) {
                            Text("Request").tag(InspectorTab.request)
                            Text("Response").tag(InspectorTab.response)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                        switch tab {
                        case .request:
                            requestTab(for: request)
                        case .response:
                            responseTab(for: request)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            ContentUnavailableView(
                "No request selected",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Choose a row in the request list to inspect headers and bodies.")
            )
        }
    }

    /// Response headers and body, or a line that says why there is no response yet or at all.
    @ViewBuilder
    private func responseTab(for request: CapturedRequest) -> some View {
        if !request.isComplete {
            Text("Waiting for response…")
                .foregroundStyle(.secondary)
        } else if request.statusCode == nil {
            Text("No response")
                .foregroundStyle(.secondary)
        } else {
            NameValueList(title: "Headers", rows: sortedRows(request.responseHeaders), separator: ": ")
            BodySection(data: request.responseBody)
        }
    }

    /// Query parameters (only when the URL has a query), request headers, and request body.
    @ViewBuilder
    private func requestTab(for request: CapturedRequest) -> some View {
        let queryItems = request.queryItems
        if !queryItems.isEmpty {
            NameValueList(
                title: "Query parameters",
                rows: queryItems.map { ($0.name, $0.value ?? "") },
                separator: "="
            )
        }
        NameValueList(title: "Headers", rows: sortedRows(request.requestHeaders), separator: ": ")
        BodySection(data: request.requestBody)
    }

    /// Headers sorted by name, without regard to case.
    private func sortedRows(_ headers: [String: String]) -> [(name: String, value: String)] {
        headers
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { ($0.key, $0.value) }
    }
}

/// The inspector tabs. The raw value is saved in `UserDefaults`.
private enum InspectorTab: String {
    case request
    case response
}

/// Status badge, method, duration, and response size; the full URL (selectable); the date and time and the app;
/// Copy URL and Copy as cURL. It does not scroll.
private struct InspectorHeader: View {
    let request: CapturedRequest
    let appName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(request.statusText)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(request.statusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(request.statusColor.opacity(0.15), in: .rect(cornerRadius: 4))
                Text(request.method)
                    .fontWeight(.semibold)
                if !measurements.isEmpty {
                    Text("· " + measurements.joined(separator: " · "))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Text(request.url)
                .font(.callout.monospaced())
                .textSelection(.enabled)
            Text(startText)
                .foregroundStyle(.secondary)
            HStack {
                Button("Copy URL") { Pasteboard.copy(request.url) }
                Button("Copy as cURL") { Pasteboard.copy(CurlBuilder.make(from: request)) }
            }
            .controlSize(.small)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Duration and response size, only the ones that are known.
    private var measurements: [String] {
        [
            request.duration.map { _ in request.durationText },
            request.responseBody.map { _ in request.sizeText },
        ].compactMap { $0 }
    }

    /// "Nov 5, 09:07:06 · NetworkTrail Demo": the start of the request and the app.
    private var startText: String {
        let start = request.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute().second())
        guard let appName else { return start }
        return "\(start) · \(appName)"
    }
}

/// For a call without a response: a short title (`CapturedError.title`), the domain and code,
/// and the full error text in Details. A gray box; only the icon is red.
private struct ErrorBanner: View {
    let error: CapturedError

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(error.title)
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            // `verbatim` keeps the code as sent: "-1003", not "-1,003".
            Text(verbatim: "\(error.domain) · \(error.code)")
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
            DisclosureGroup("Details") {
                Text(error.debugDescription)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }
}

/// "Headers · 6", then names and values in two aligned columns, or "None".
/// Right-click a row: Copy Value, or Copy All with one "name<separator>value" line for each row.
private struct NameValueList: View {
    let title: String
    let rows: [(name: String, value: String)]
    let separator: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) · \(rows.count)")
                .font(.headline)
            if rows.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 4) {
                    ForEach(rows.indices, id: \.self) { index in
                        let row = rows[index]
                        GridRow {
                            Text(row.name)
                                .foregroundStyle(.secondary)
                                .contextMenu { menu(for: row) }
                            Text(row.value)
                                .contextMenu { menu(for: row) }
                        }
                    }
                }
                .font(.callout.monospaced())
            }
        }
    }

    @ViewBuilder
    private func menu(for row: (name: String, value: String)) -> some View {
        Button("Copy Value") { Pasteboard.copy(row.value) }
        Button("Copy All") {
            Pasteboard.copy(rows.map { "\($0.name)\(separator)\($0.value)" }.joined(separator: "\n"))
        }
    }
}
