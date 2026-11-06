import SwiftUI
import NetworkTrailWire

/// All, Failed, Slow, and Duplicates above the request table, each with its count in the selected app
/// (`SessionStore.insights`, not narrowed by the search text). One filter is active; click it again to show all.
/// A scope bar, like the search bar of the Finder.
struct HealthFilterBar: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        let insights = store.insights
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(HealthFilter.allCases) { filter in
                    Toggle(isOn: isActive(filter)) {
                        Text(filter.title) + Text(" \(count(of: filter, in: insights))").foregroundStyle(.secondary)
                    }
                    .help(filter.rule)
                }
                Spacer()
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

extension HealthFilter {
    var title: String {
        switch self {
        case .all: "All"
        case .failed: "Failed"
        case .slow: "Slow"
        case .duplicates: "Duplicates"
        }
    }

    /// The tooltip: the rule of the filter.
    var rule: String {
        let limits = HealthLimits.defaults
        switch self {
        case .all:
            return "All requests of the selection"
        case .failed:
            return "Status 400–599, or an error without a response. Calls that the app cancelled do not count."
        case .slow:
            return "Finished calls that took longer than \(seconds(limits.slowDuration))"
        case .duplicates:
            return "Calls with the same method, URL, and body as a call of the same app that started at most "
                + "\(seconds(limits.duplicateWindow)) before. The first call does not count."
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
