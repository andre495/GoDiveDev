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
                                toggleSelection(for: row.id)
                            } label: {
                                HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                                    ExploreDiveSiteRow(data: row)
                                        .equatable()

                                    if selectedSiteIDs.contains(row.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppTheme.Colors.tabSelected)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("TripPlannedSitePicker.Row.\(row.id.uuidString)")
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
                        action: {
                            onCancel()
                            dismiss()
                        },
                        accessibilityIdentifier: DiveTripPresentation.plannedSitePickerCancelAccessibilityIdentifier
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: {
                            onDone()
                            dismiss()
                        },
                        accessibilityIdentifier: DiveTripPresentation.plannedSitePickerDoneAccessibilityIdentifier
                    )
                }
            }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .accessibilityIdentifier("TripPlannedSitePicker.Root")
    }

    private func toggleSelection(for siteID: UUID) {
        if selectedSiteIDs.contains(siteID) {
            selectedSiteIDs.remove(siteID)
        } else {
            selectedSiteIDs.insert(siteID)
        }
    }
}
