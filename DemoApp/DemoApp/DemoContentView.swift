import SwiftUI

/// Buttons that fire a few `URLSession` calls to httpbin so you can see rows in NetworkTrail.
struct DemoContentView: View {
    @State private var log = "Tap a button to send sample HTTP traffic."
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("NetworkTrail Demo")
                    .font(.title2.bold())
                Text("Run the Mac app, then trigger requests below. Traffic appears live in NetworkTrail.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("GET httpbin") { run(.get) }
                    Button("POST httpbin") { run(.post) }
                    Button("Run all") { run(.all) }
                }
                .disabled(isLoading)

                ScrollView {
                    Text(log)
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding()
            .navigationTitle("Demo")
        }
    }

    private enum Sample {
        case get, post, all
    }

    /// GET, POST, or both plus a 418 status call. Updates the on-screen log.
    private func run(_ sample: Sample) {
        isLoading = true
        log = "Sending…\n"
        Task {
            do {
                switch sample {
                case .get:
                    try await sendGET()
                case .post:
                    try await sendPOST()
                case .all:
                    try await sendGET()
                    try await sendPOST()
                    try await sendStatus()
                }
                await MainActor.run {
                    log += "\nDone. Check NetworkTrail on your Mac."
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    log += "\nError: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func sendGET() async throws {
        let url = URL(string: "https://httpbin.org/get?demo=networktrail")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        await append("GET \(url.absoluteString) → \(code) (\(data.count) bytes)")
    }

    private func sendPOST() async throws {
        var request = URLRequest(url: URL(string: "https://httpbin.org/post")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = #"{"hello":"NetworkTrail"}"#.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        await append("POST /post → \(code) (\(data.count) bytes)")
    }

    private func sendStatus() async throws {
        let url = URL(string: "https://httpbin.org/status/418")!
        let (_, response) = try await URLSession.shared.data(from: url)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        await append("GET /status/418 → \(code)")
    }

    @MainActor
    private func append(_ line: String) {
        log += line + "\n"
    }
}
