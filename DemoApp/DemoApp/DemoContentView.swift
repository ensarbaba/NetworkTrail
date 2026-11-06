import SwiftUI

/// Test calls for NetworkTrail: one row for each call, with its last result.
/// Run all sends the calls one after the other. A failed call does not stop the others.
struct DemoContentView: View {
    @State private var results: [DemoCall: CallResult] = [:]
    @State private var isRunning = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Run all") {
                        Task { await run(DemoCall.allCases) }
                    }
                } footer: {
                    Text("Start NetworkTrail on the Mac first. Each call shows there.")
                }
                Section("Calls") {
                    ForEach(DemoCall.allCases) { call in
                        Button {
                            Task { await run([call]) }
                        } label: {
                            row(for: call)
                        }
                    }
                }
            }
            .disabled(isRunning)
            .navigationTitle("NetworkTrail Demo")
        }
    }

    private func row(for call: DemoCall) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(call.title)
                Text(call.detail)
                    .font(.caption)
                    // `Color.secondary`: `.secondary` in a button label is a lighter tint color.
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
            if let result = results[call] {
                Text(result.text)
                    .font(.caption)
                    .foregroundStyle(result.color)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
    }

    private func run(_ calls: [DemoCall]) async {
        isRunning = true
        for call in calls {
            results[call] = CallResult(text: "Sending…", color: .secondary)
            results[call] = await send(call)
        }
        isRunning = false
    }

    /// Status and size, for example "200 · 395 bytes", or the error.
    private func send(_ call: DemoCall) async -> CallResult {
        do {
            switch call {
            case .duplicate:
                // Three times at once, like a screen that loads the same data more than one time.
                async let first = URLSession.shared.data(for: call.request)
                async let second = URLSession.shared.data(for: call.request)
                async let third = URLSession.shared.data(for: call.request)
                let codes = try await [first, second, third].map { statusCode(of: $0.1) }
                let text = Set(codes).count == 1 ? "\(codes[0]) ×3" : codes.map(String.init).joined(separator: ", ")
                return CallResult(text: text, color: color(for: codes.max() ?? 0))
            default:
                let (data, response) = try await URLSession.shared.data(for: call.request)
                let code = statusCode(of: response)
                let size = Int64(data.count).formatted(.byteCount(style: .file, spellsOutZero: false))
                return CallResult(text: "\(code) · \(size)", color: color(for: code))
            }
        } catch {
            return CallResult(text: error.localizedDescription, color: .red)
        }
    }

    private func statusCode(of response: URLResponse) -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? 0
    }

    /// Green for 2xx, orange for 4xx, red for 5xx, the same colors as NetworkTrail.
    private func color(for code: Int) -> Color {
        switch code {
        case 200..<300: .green
        case 400..<500: .orange
        case 500...: .red
        default: .secondary
        }
    }
}

private struct CallResult {
    let text: String
    let color: Color
}

/// The test calls. Most go to httpbin.org.
private enum DemoCall: CaseIterable, Identifiable {
    case get
    case post
    case teapot
    case duplicate
    case slow
    case notFound
    case serverError
    case badHost
    case image

    var id: Self { self }

    var title: String {
        switch self {
        case .get: "GET"
        case .post: "POST JSON"
        case .teapot: "Teapot"
        case .duplicate: "Duplicate"
        case .slow: "Slow"
        case .notFound: "Not found"
        case .serverError: "Server error"
        case .badHost: "Bad host"
        case .image: "Image"
        }
    }

    var detail: String {
        switch self {
        case .duplicate: "Same GET 3 times at once"
        case .badHost: url.host() ?? ""
        default: url.path() + (url.query().map { "?" + $0 } ?? "")
        }
    }

    var url: URL {
        switch self {
        case .get: URL(string: "https://httpbin.org/get?demo=networktrail")!
        case .post: URL(string: "https://httpbin.org/post")!
        case .teapot: URL(string: "https://httpbin.org/status/418")!
        case .duplicate: URL(string: "https://httpbin.org/get?demo=duplicate")!
        // The server waits 2 s before it answers.
        case .slow: URL(string: "https://httpbin.org/delay/2")!
        case .notFound: URL(string: "https://httpbin.org/status/404")!
        case .serverError: URL(string: "https://httpbin.org/status/500")!
        // `.invalid` is a reserved top-level domain (RFC 2606), so the DNS lookup always fails.
        case .badHost: URL(string: "https://no-such-host.invalid/")!
        case .image: URL(string: "https://httpbin.org/image/png")!
        }
    }

    var request: URLRequest {
        var request = URLRequest(url: url)
        if self == .post {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(#"{"hello":"NetworkTrail"}"#.utf8)
        }
        return request
    }
}
