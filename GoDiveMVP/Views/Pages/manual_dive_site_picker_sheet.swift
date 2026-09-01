import SwiftData
import SwiftUI

/// Single-select catalog **`DiveSite`** picker for manual dive or snorkel entry.
struct ManualDiveEntrySitePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedSiteID: UUID?
    let sites: [DiveSite]

    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredSites: [DiveSite] {
        ExploreDiveSiteListSearch.filtering(sites, query: searchQuery)
    }

    private var filteredSiteRows: [ExploreDiveSiteRowDisplayData] {
        ExploreDiveSiteListDisplay.rowData(for: filteredSites, trailingStyle: .plannedTrip)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if sites.isEmpty {
                    ContentUnavailableView(
                        "No dive sites",
                        systemImage: "mappin.and.ellipse",
                        description: Text("Dive sites from the catalog will appear here.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredSiteRows.isEmpty {
                    ContentUnavailableView.search(text: searchQuery)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TaggingSheetListChrome {
                        ForEach(Array(filteredSiteRows.enumerated()), id: \.element.id) { index, row in
                            TaggingSheetListRowContainer(showsDivider: index < filteredSiteRows.count - 1) {
                                TaggingSheetSelectionRow(
                                    title: row.displayName,
                                    subtitle: siteSubtitle(for: row),
                                    isSelected: selectedSiteID == row.id,
                                    accessibilityValueSelected: "Selected",
                                    accessibilityValueUnselected: "Not selected",
                                    onTap: {
                                        selectedSiteID = row.id
                                        dismiss()
                                    },
                                    leading: {
                                        TaggingSheetSymbolLeadingArt(
                                            systemName: TaggingSheetSelectionPresentation.sitePlaceholderSystemName
                                        )
                                    }
                                )
                                .accessibilityIdentifier("ManualDiveEntrySitePicker.Row.\(row.id.uuidString)")
                            }
                        }
                    }
                }

                TaggingSheetBottomSearchChrome(
                    searchText: $searchQuery,
                    isSearchFocused: $isSearchFocused,
                    placeholder: "Search dive sites",
                    searchFieldAccessibilityIdentifier: "ManualDiveEntrySitePicker.SearchField",
                    cancelAccessibilityIdentifier: "ManualDiveEntrySitePicker.SearchCancel"
                )
            }
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

    private func siteSubtitle(for row: ExploreDiveSiteRowDisplayData) -> String? {
        let parts = [row.coordinateLine, row.placeLine]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n")
    }
}
