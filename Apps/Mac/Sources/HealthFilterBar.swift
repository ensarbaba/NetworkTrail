import SwiftUI
import NetworkTrailWire

/// All, Failed, Slow, and Duplicates above the request table, each with its count in the selected app
/// (`SessionStore.insights`, not narrowed by the search text). One filter is active; click it again to show all.
/// A scope bar, like the search bar of the Finder. The (i) button at the end opens the rules and the limits.
struct HealthFilterBar: View {
    @Environment(SessionStore.self) private var store
    @State private var isShowingRules = false

    var body: some View {
        let insights = store.insights
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(HealthFilter.allCases) { filter in
                    Toggle(isOn: isActive(filter)) {
                        Text(filter.title) + Text(" \(count(of: filter, in: insights))").foregroundStyle(.secondary)
                    }
                    .help(filter.rule(limits: store.healthLimits))
                }
                Spacer()
                Button {
                    isShowingRules.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .help("Health rules and limits")
                .accessibilityLabel("Health rules")
                .popover(isPresented: $isShowingRules, arrowEdge: .bottom) {
                    HealthRulesView()
                }
            }
            .toggleStyle(.button)
            .buttonStyle(.accessoryBar)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            Divider()
        }
    }

    /// On selects the filter. Off (a click on the active filter) shows all requests.
    private func isActive(_ filter: HealthFilter) -> Binding<Bool> {
        Binding(
            get: { store.healthFilter == filter },
            set: { store.healthFilter = $0 ? filter : .all }
        )
    }

    private func count(of filter: HealthFilter, in insights: SessionInsights) -> Int {
        switch filter {
        case .all: store.scopedRequests.count
        case .failed: insights.failed.count
        case .slow: insights.slow.count
        case .duplicates: insights.duplicates.count
        }
    }
}

/// The rules of Failed, Slow, and Duplicates, with the Slow limit and the Duplicate window to edit.
private struct HealthRulesView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 12) {
            Text("Health rules")
                .font(.headline)
            rule(.failed)
            VStack(alignment: .leading, spacing: 6) {
                rule(.slow)
                LimitField(title: "Limit", seconds: $store.healthLimits.slowDuration)
            }
            VStack(alignment: .leading, spacing: 6) {
                rule(.duplicates)
                LimitField(title: "Window", seconds: $store.healthLimits.duplicateWindow)
            }
            Button("Reset to Defaults") {
                store.healthLimits = .defaults
            }
            .disabled(store.healthLimits == .defaults)
        }
        .padding()
        .frame(width: 300)
    }

    private func rule(_ filter: HealthFilter) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(filter.title)
                .fontWeight(.semibold)
            Text(filter.rule(limits: nil))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A limit in seconds: a number field and a stepper in steps of 0.5 s, from 0.1 s to 60 s.
private struct LimitField: View {
    let title: String
    @Binding var seconds: TimeInterval

    private static let range: ClosedRange<TimeInterval> = 0.1...60

    var body: some View {
        // A typed value outside the range becomes the nearest end of the range.
        let clamped = Binding(
            get: { seconds },
            set: { seconds = min(max($0, Self.range.lowerBound), Self.range.upperBound) }
        )
        HStack(spacing: 4) {
            Text(title)
            TextField(title, value: clamped, format: .number.precision(.fractionLength(0...2)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 50)
            Stepper(title, value: clamped, in: Self.range, step: 0.5)
                .labelsHidden()
            Text("s")
        }
    }
}

extension HealthFilter {
    var title: String {
        switch self {
        case .all: "All"
        case .failed: "Failed"
        case .slow: "Slow"
        case .duplicates: "Duplicates"
        }
    }

    /// The rule of the filter. With `limits`, it names the values (for the tooltips);
    /// without, it names "the limit" and "the window" (for the popover, which shows the values in fields).
    func rule(limits: HealthLimits?) -> String {
        switch self {
        case .all:
            return "All requests of the selection."
        case .failed:
            return "Status 400–599, or an error without a response. Calls that the app cancelled do not count."
        case .slow:
            return "Finished calls that took longer than \(limits.map { seconds($0.slowDuration) } ?? "the limit")."
        case .duplicates:
            return "Calls with the same method, URL, and body as an earlier call of the same app within "
                + "\(limits.map { seconds($0.duplicateWindow) } ?? "the window"). The first call does not count."
        }
    }

    /// The title of the empty state when the filter shows no request.
    var emptyTitle: String {
        switch self {
        case .all: "No requests"
        case .failed: "No failed requests"
        case .slow: "No slow requests"
        case .duplicates: "No duplicate requests"
        }
    }

    /// "1 s" or "0.5 s".
    private func seconds(_ interval: TimeInterval) -> String {
        interval.formatted(.number.precision(.fractionLength(0...2))) + " s"
    }
}
