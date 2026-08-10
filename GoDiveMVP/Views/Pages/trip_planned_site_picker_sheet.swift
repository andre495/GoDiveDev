import SwiftData
import SwiftUI

/// Multi-select catalog **`DiveSite`** rows for trip planning (blue overview-panel modal).
struct TripPlannedSitePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedSiteIDs: Set<UUID>
    let sites: [DiveSite]
    var onCancel: () -> Void = {}
    var onDone: () -> Void = {}

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
                                    isSelected: selectedSiteIDs.contains(row.id),
                                    accessibilityValueSelected: "Selected",
                                    accessibilityValueUnselected: "Not selected",
                                    onTap: { toggleSelection(for: row.id) },
                                    leading: {
                                        TaggingSheetSymbolLeadingArt(
                                            systemName: TaggingSheetSelectionPresentation.sitePlaceholderSystemName
                                        )
                                    }
                                )
                                .accessibilityIdentifier("TripPlannedSitePicker.Row.\(row.id.uuidString)")
                            }
                        }
                    }
                }

                TaggingSheetBottomSearchChrome(
                    searchText: $searchQuery,
                    isSearchFocused: $isSearchFocused,
                    placeholder: "Search dive sites",
                    searchFieldAccessibilityIdentifier: "TripPlannedSitePicker.SearchField",
                    cancelAccessibilityIdentifier: "TripPlannedSitePicker.SearchCancel"
                )
            }
            .taggingSheetToolbar(
                cancelAccessibilityIdentifier: DiveTripPresentation.plannedSitePickerCancelAccessibilityIdentifier,
                doneAccessibilityIdentifier: DiveTripPresentation.plannedSitePickerDoneAccessibilityIdentifier,
                onCancel: {
                    onCancel()
                    dismiss()
                },
                onDone: {
                    onDone()
                    dismiss()
                }
            )
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .accessibilityIdentifier("TripPlannedSitePicker.Root")
    }

    private func siteSubtitle(for row: ExploreDiveSiteRowDisplayData) -> String? {
        let parts = [row.coordinateLine, row.placeLine]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n")
    }

    private func toggleSelection(for siteID: UUID) {
        if selectedSiteIDs.contains(siteID) {
            selectedSiteIDs.remove(siteID)
        } else {
            selectedSiteIDs.insert(siteID)
        }
    }
}
