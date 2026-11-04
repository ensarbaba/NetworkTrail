import SwiftUI
import NetworkTrailWire

/// The live request table (`SessionStore.filteredRequests`). A click selects a row; double-click or Return
/// opens the inspector. The columns that show are saved, one set with the inspector and one without it.
struct RequestTable: View {
    @Environment(SessionStore.self) private var store
    /// Column choices: one set while the inspector shows, one while it is hidden. JSON in `UserDefaults`,
    /// because `@SceneStorage` is lost when macOS closes the windows on quit.
    @AppStorage("requestTable.columns.withInspector") private var columnsWithInspector = Data()
    @AppStorage("requestTable.columns.withoutInspector") private var columnsWithoutInspector = Data()

    var body: some View {
        @Bindable var store = store
        // While the inspector shows, Start, Host, and Size are hidden unless the user shows them.
        let secondaryColumnVisibility: Visibility = store.isInspectorShown ? .hidden : .automatic
        Table(
            store.filteredRequests,
            selection: $store.selectedRequestID,
            columnCustomization: columnCustomization
        ) {
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
            }
            .width(70)
            .customizationID("duration")
        }
        .contextMenu(forSelectionType: CapturedRequest.ID.self) { ids in
            if ids.count == 1, let request = store.requests.first(where: { ids.contains($0.id) }) {
                Button("Copy URL") { Pasteboard.copy(request.url) }
                Button("Copy as cURL") { Pasteboard.copy(CurlBuilder.make(from: request)) }
            }
        } primaryAction: { ids in
            // Double-click or Return on a row.
            if !ids.isEmpty {
                store.isInspectorShown = true
            }
        }
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
