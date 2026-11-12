import SwiftUI
import NetworkTrailWire

/// The live request table (`SessionStore.filteredRequests`). A click selects a row; double-click or Return
/// opens the inspector. The columns that show are saved, one set with the inspector and one without it.
/// A "Relaunched" divider row separates the requests of two launches of an app (`RelaunchSection`).
/// A duplicate has an icon in the first column; a slow call has an orange duration (`SessionStore.insights`).
struct RequestTable: View {
    @Environment(SessionStore.self) private var store
    /// Column choices: one set while the inspector shows, one while it is hidden. JSON in `UserDefaults`,
    /// because `@SceneStorage` is lost when macOS closes the windows on quit.
    @AppStorage("requestTable.columns.withInspector") private var columnsWithInspector = Data()
    @AppStorage("requestTable.columns.withoutInspector") private var columnsWithoutInspector = Data()

    var body: some View {
        @Bindable var store = store
        // While the inspector shows, Start, Host, and Size are hidden unless the user shows them.
        // The duplicate and Date columns are always hidden until the user shows them.
        let secondaryColumnVisibility: Visibility = store.isInspectorShown ? .hidden : .automatic
        let (newestRequests, relaunchSections) = RelaunchSection.split(store.filteredRequests)
        let insights = store.insights
        Table(
            of: CapturedRequest.self,
            selection: $store.selectedRequestID,
            columnCustomization: columnCustomization
        ) {
            // A word and the icon: the header's show/hide menu uses the same title and drops the icon,
            // so an icon-only title gives a blank menu item. The word comes first, because the menu keeps
            // the space next to the dropped icon, and a leading space moves the item out of line.
            TableColumn("Duplicate \(Image(systemName: "repeat"))") { request in
                if let earlierStart = insights.duplicates[request.id] {
                    Image(systemName: "repeat")
                        .foregroundStyle(.secondary)
                        .help(repeatsCallText(at: earlierStart))
                        .accessibilityLabel(repeatsCallText(at: earlierStart))
                }
            }
            .width(90)
            .customizationID("duplicate")
            .defaultVisibility(.hidden)
            TableColumn("Date") { request in
                // Month and day in the Mac locale, for example "Nov 5". No year: requests stay only while the app runs.
                Text(request.createdAt, format: .dateTime.month(.abbreviated).day())
                    .monospacedDigit()
            }
            .width(min: 45, ideal: 60, max: 90)
            .customizationID("date")
            .defaultVisibility(.hidden)
            TableColumn("Start") { request in
                Text(request.createdAt, format: .dateTime.hour().minute().second())
                    .monospacedDigit()
            }
            .width(min: 60, ideal: 80, max: 110)
            .customizationID("start")
            .defaultVisibility(secondaryColumnVisibility)
            TableColumn("Status") { request in
                Text(request.statusText)
                    .fontWeight(.semibold)
                    .foregroundStyle(request.statusColor)
                    .monospacedDigit()
            }
            .width(60)
            .customizationID("status")
            .disabledCustomizationBehavior(.visibility)
            TableColumn("Method") { request in
                Text(request.method)
            }
            .width(70)
            .customizationID("method")
            TableColumn("Host") { request in
                Text(request.host)
                    .lineLimit(1)
            }
            .width(min: 100, ideal: 150, max: 260)
            .customizationID("host")
            .defaultVisibility(secondaryColumnVisibility)
            TableColumn("Path") { request in
                Text(request.pathAndQuery)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(request.url)
            }
            .customizationID("path")
            .disabledCustomizationBehavior(.visibility)
            TableColumn("Size") { request in
                Text(request.sizeText)
                    .monospacedDigit()
            }
            .width(70)
            .customizationID("size")
            .defaultVisibility(secondaryColumnVisibility)
            TableColumn("Duration") { request in
                Text(request.durationText)
                    .monospacedDigit()
                    // `HierarchicalShapeStyle.primary`, not `Color.primary`: the same default style as the other cells.
                    .foregroundStyle(
                        insights.slow.contains(request.id) ? AnyShapeStyle(Color.orange) : AnyShapeStyle(HierarchicalShapeStyle.primary)
                    )
            }
            .width(70)
            .customizationID("duration")
        } rows: {
            ForEach(newestRequests) { request in
                TableRow(request)
            }
            ForEach(relaunchSections) { section in
                Section {
                    ForEach(section.requests) { request in
                        TableRow(request)
                    }
                } header: {
                    Label(relaunchText(for: section), systemImage: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contextMenu(forSelectionType: CapturedRequest.ID.self) { ids in
            if ids.count == 1, let request = store.requests.first(where: { ids.contains($0.id) }) {
                Button("Copy URL") { Pasteboard.copy(request.url) }
                Button("Copy as cURL") { Pasteboard.copy(CurlBuilder.make(from: request)) }
                Button("Copy Request and Response") { Pasteboard.copy(store.requestAndResponseText(of: request)) }
            }
        } primaryAction: { ids in
            // Double-click or Return on a row.
            if !ids.isEmpty {
                store.isInspectorShown = true
            }
        }
    }

    /// "Relaunched 08:10:05 · NetworkTrail Demo": the start of the new launch and the app name.
    private func relaunchText(for section: RelaunchSection) -> String {
        let time = section.launchedAt.formatted(.dateTime.hour().minute().second())
        guard let appName = store.client(id: section.clientID)?.appName else {
            return "Relaunched \(time)"
        }
        return "Relaunched \(time) · \(appName)"
    }

    /// The column choices of the current inspector state, read from and written to `@AppStorage`.
    private var columnCustomization: Binding<TableColumnCustomization<CapturedRequest>> {
        let storage = store.isInspectorShown ? $columnsWithInspector : $columnsWithoutInspector
        return Binding(
            get: { (try? JSONDecoder().decode(TableColumnCustomization<CapturedRequest>.self, from: storage.wrappedValue)) ?? TableColumnCustomization() },
            set: { storage.wrappedValue = (try? JSONEncoder().encode($0)) ?? Data() }
        )
    }
}
