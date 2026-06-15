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
                        ForEach(filteredSites, id: \.id) { site in
                            Button {
                                toggleSelection(for: site.id)
                            } label: {
                                HStack(spacing: AppTheme.Spacing.md) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(site.siteName)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.textPrimary)
                                        let country = site.country.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if !country.isEmpty {
                                            Text(country)
                                                .font(.subheadline)
                                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                    if selectedSiteIDs.contains(site.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppTheme.Colors.tabSelected)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("TripPlannedSitePicker.Row.\(site.id.uuidString)")
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
