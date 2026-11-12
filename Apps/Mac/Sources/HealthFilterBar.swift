import SwiftUI
import NetworkTrailWire

/// All, Failed, Slow, and Duplicates above the request table, each with its count in the selected app
/// (`SessionStore.insights`: without hidden hosts, not narrowed by the search text). One filter is active;
/// click it again to show all.
/// A scope bar, like the search bar of the Finder. The "Rules…" button at the end opens the rules and the limits.
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
                // A text button, not an icon: an (i) icon looked like help text and hid the limits.
                // The same small push button as "Setup Snippet" under the table.
                Button("Rules…") {
                    isShowingRules.toggle()
                }
                .buttonStyle(.automatic)
                .controlSize(.small)
                .help("Show the health rules and change the Slow and Duplicates limits")
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
        case .all: store.visibleRequests.count
        case .failed: insights.failed.count
        case .slow: insights.slow.count
        case .duplicates: insights.duplicates.count
        }
    }
}

/// The rules of Failed, Slow, and Duplicates, one row each: the name with its count, then the rule as a sentence.
/// The Slow and Duplicates sentences hold their limit, so the value is in the text that it changes.
/// The counts are the counts of the chips, so they change while the user edits a limit.
private struct HealthRulesView: View {
    @Environment(SessionStore.self) private var store
    /// The limit field that has the cursor. Nil when the popover opens, so that a typed key changes no limit.
    @FocusState private var focusedLimit: LimitKind?

    var body: some View {
        @Bindable var store = store
        let insights = store.insights
        VStack(alignment: .leading, spacing: 10) {
            Text("Health rules")
                .font(.headline)
            row(.failed, count: insights.failed.count) {
                Text("Status 400–599, or no response")
            } note: {
                Text("Fixed. Calls that the app cancelled do not count.")
            }
            Divider()
            row(.slow, count: insights.slow.count) {
                HStack(spacing: 4) {
                    Text("Took longer than")
                    LimitField(accessibilityTitle: "Slow limit in seconds", seconds: $store.healthLimits.slowDuration)
                        .focused($focusedLimit, equals: .slow)
                }
            } note: {
                Text("Only finished calls. Default \(secondsText(HealthLimits.defaults.slowDuration)).")
            }
            Divider()
            row(.duplicates, count: insights.duplicates.count) {
                HStack(spacing: 4) {
                    Text("Same call again within")
                    LimitField(accessibilityTitle: "Duplicates window in seconds", seconds: $store.healthLimits.duplicateWindow)
                        .focused($focusedLimit, equals: .duplicates)
                }
            } note: {
                Text(
                    "Same app, method, URL, and body. The first call does not count. "
                        + "Default \(secondsText(HealthLimits.defaults.duplicateWindow))."
                )
            }
            Button("Restore Defaults") {
                store.healthLimits = .defaults
            }
            .disabled(store.healthLimits == .defaults)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            // The popover puts the cursor in its first field. Take it out after that happens.
            DispatchQueue.main.async {
                focusedLimit = nil
            }
        }
    }

    private enum LimitKind {
        case slow
        case duplicates
    }

    /// One rule: "Slow 1" in a fixed-width column on the left, the rule and a secondary note on the right.
    private func row(
        _ filter: HealthFilter,
        count: Int,
        @ViewBuilder rule: () -> some View,
        @ViewBuilder note: () -> some View
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            (Text(filter.title).fontWeight(.semibold) + Text(" \(count)").foregroundStyle(.secondary))
                .frame(width: 100, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                rule()
                note()
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A limit in seconds: a number field, a stepper in steps of 0.5 s, and "s". From 0.1 s to 60 s.
private struct LimitField: View {
    /// The name for VoiceOver. The field shows no label: the sentence around it names it.
    let accessibilityTitle: String
    @Binding var seconds: TimeInterval

    private static let range: ClosedRange<TimeInterval> = 0.1...60

    var body: some View {
        // A typed value outside the range becomes the nearest end of the range.
        let clamped = Binding(
            get: { seconds },
            set: { seconds = min(max($0, Self.range.lowerBound), Self.range.upperBound) }
        )
        HStack(spacing: 4) {
            TextField(accessibilityTitle, value: clamped, format: .number.precision(.fractionLength(0...2)))
                .labelsHidden()
                .accessibilityLabel(accessibilityTitle)
                .multilineTextAlignment(.trailing)
                .frame(width: 50)
            Stepper(accessibilityTitle, value: clamped, in: Self.range, step: 0.5)
                .labelsHidden()
            Text("s")
        }
    }
}

/// "1 s" or "0.5 s".
private func secondsText(_ interval: TimeInterval) -> String {
    interval.formatted(.number.precision(.fractionLength(0...2))) + " s"
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

    /// The rule of the filter with the current values, for the tooltips of the chips and the inspector badges.
    func rule(limits: HealthLimits) -> String {
        switch self {
        case .all:
            return "All requests of the selection."
        case .failed:
            return "Status 400–599, or an error without a response. Calls that the app cancelled do not count."
        case .slow:
            return "Finished calls that took longer than \(secondsText(limits.slowDuration))."
        case .duplicates:
            return "Calls with the same method, URL, and body as an earlier call of the same app within "
                + "\(secondsText(limits.duplicateWindow)). The first call does not count."
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
}
