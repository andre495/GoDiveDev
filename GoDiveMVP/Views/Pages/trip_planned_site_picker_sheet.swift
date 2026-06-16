import SwiftData
import SwiftUI

/// Multi-select catalog **`DiveSite`** rows for trip planning.
struct TripPlannedSitePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedSiteIDs: Set<UUID>
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
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .searchable(text: $searchQuery, prompt: "Search dive sites")
            .navigationTitle(DiveTripPresentation.plannedSitesSectionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("TripPlannedSitePicker.Done")
                }
            }
        }
        .appSheetPresentationChrome()
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
