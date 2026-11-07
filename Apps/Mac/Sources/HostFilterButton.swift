import SwiftUI
import NetworkTrailWire

/// The Hosts button in the toolbar. It opens a popover with a checkbox for each host of the selected app.
/// An unchecked host is hidden in all apps (`SessionStore.hiddenHosts`). The icon is filled while a host is hidden.
struct HostFilterButton: View {
    @Environment(SessionStore.self) private var store
    @State private var isShowingHosts = false

    var body: some View {
        let hiddenCount = store.hiddenHosts.count
        Button {
            isShowingHosts.toggle()
        } label: {
            if hiddenCount == 0 {
                Label("Hosts", systemImage: "line.3.horizontal.decrease.circle")
            } else {
                // Filled and in the accent color while a filter is active, as in Mail.
                Label("Hosts", systemImage: "line.3.horizontal.decrease.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .help(hiddenCount == 0 ? "Show or hide hosts" : hiddenHostsText(hiddenCount))
        .popover(isPresented: $isShowingHosts, arrowEdge: .bottom) {
            HostFilterView()
        }
    }

    /// "1 host hidden" or "3 hosts hidden".
    private func hiddenHostsText(_ count: Int) -> String {
        count == 1 ? "1 host hidden" : "\(count) hosts hidden"
    }
}

/// The popover: a field that narrows the list, one row for each host (a checkbox, the host, its request count),
/// then Show All and Hide All for the rows in the list. The hosts are the hosts of the selected app, and
/// the hidden hosts (also with 0 requests, so that the user can always show them again). The order is A to Z:
/// NetworkTrail does not rank or label hosts, and only the user hides a host.
private struct HostFilterView: View {
    @Environment(SessionStore.self) private var store
    @State private var filterText = ""
    /// The height of all rows, so that the list is only as tall as its rows, up to `maxListHeight`.
    @State private var listHeight: CGFloat = 0

    private static let maxListHeight: CGFloat = 320

    var body: some View {
        let allRows = HostCount.make(from: store.scopedRequests, alsoListing: store.hiddenHosts)
        let trimmed = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = trimmed.isEmpty ? allRows : allRows.filter { $0.host.localizedCaseInsensitiveContains(trimmed) }
        VStack(alignment: .leading, spacing: 8) {
            Text("Hosts")
                .font(.headline)
            TextField("Filter hosts", text: $filterText)
                .textFieldStyle(.roundedBorder)
            if rows.isEmpty {
                Text(allRows.isEmpty ? "No hosts yet" : "No host matches “\(trimmed)”")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(rows) { row in
                            HStack {
                                Toggle(isOn: isShown(row.host)) {
                                    Text(row.host)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .toggleStyle(.checkbox)
                                .help(row.host)
                                Spacer(minLength: 8)
                                Text("\(row.count)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .help(requestCountText(row.count))
                            }
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
                }
                .frame(height: min(listHeight, Self.maxListHeight))
            }
            Divider()
            HStack {
                Button("Show All") {
                    store.hiddenHosts.subtract(rows.map(\.host))
                }
                .disabled(rows.allSatisfy { !store.hiddenHosts.contains($0.host) })
                Button("Hide All") {
                    store.hiddenHosts.formUnion(rows.map(\.host))
                }
                .disabled(rows.allSatisfy { store.hiddenHosts.contains($0.host) })
            }
        }
        .padding()
        .frame(width: 300)
    }

    /// Checked while the host shows; unchecked hides it.
    private func isShown(_ host: String) -> Binding<Bool> {
        Binding(
            get: { !store.hiddenHosts.contains(host) },
            set: { isShown in
                if isShown {
                    store.hiddenHosts.remove(host)
                } else {
                    store.hiddenHosts.insert(host)
                }
            }
        )
    }
}
