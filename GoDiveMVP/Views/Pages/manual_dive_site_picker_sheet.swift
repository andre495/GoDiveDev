import SwiftData
import SwiftUI

/// Single-select catalog **`DiveSite`** picker for manual dive entry.
struct ManualDiveEntrySitePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedSiteID: UUID?
    let sites: [DiveSite]

    @State private var searchQuery = ""

    private var filteredSites: [DiveSite] {
        ExploreDiveSiteListSearch.filtering(sites, query: searchQuery)
    }

    private var filteredSiteRows: [ExploreDiveSiteRowDisplayData] {
        ExploreDiveSiteListDisplay.rowData(for: filteredSites, trailingStyle: .plannedTrip)
    }

    var body: some View {
        NavigationStack {
            Group {
                if sites.isEmpty {
                    ContentUnavailableView(
                        "No dive sites",
                        systemImage: "mappin.and.ellipse",
                        description: Text("Dive sites from the catalog will appear here.")
                    )
                } else {
                    List {
                        ForEach(filteredSiteRows) { row in
                            Button {
                                selectedSiteID = row.id
                                dismiss()
                            } label: {
                                HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                                    ExploreDiveSiteRow(data: row)
                                        .equatable()

                                    if selectedSiteID == row.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppTheme.Colors.tabSelected)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("ManualDiveEntrySitePicker.Row.\(row.id.uuidString)")
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .searchable(text: $searchQuery, prompt: "Search dive sites")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: "ManualDiveEntrySitePicker.Cancel"
                    )
                }
            }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .accessibilityIdentifier("ManualDiveEntrySitePicker.Root")
    }
}
