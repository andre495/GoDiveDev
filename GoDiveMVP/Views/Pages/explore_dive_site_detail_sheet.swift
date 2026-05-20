import SwiftData
import SwiftUI

/// Sheet shown when a catalog dive-site pin is tapped on **Explore**.
struct ExploreDiveSiteDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let site: DiveSite

    var body: some View {
        NavigationStack {
            List {
                if let coordinate = siteCoordinate {
                    Section("Location") {
                        LabeledContent(
                            "Coordinates",
                            value: DiveLocationMapPresentation.coordinateLabel(for: coordinate)
                        )
                    }
                }

                if !placeRows.isEmpty {
                    Section("Place") {
                        ForEach(placeRows, id: \.label) { row in
                            LabeledContent(row.label, value: row.value)
                        }
                    }
                }

                Section("Details") {
                    if let rating = site.siteRating {
                        LabeledContent("Rating", value: "\(rating) / 5")
                    } else {
                        LabeledContent("Rating", value: "Not rated")
                    }

                    if site.siteTags.isEmpty {
                        LabeledContent("Tags", value: "None")
                    } else {
                        LabeledContent("Tags", value: site.siteTags.joined(separator: ", "))
                    }

                    LabeledContent("Dives logged here", value: "\(site.diveActivities.count)")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(site.siteName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("ExploreDiveSiteDetail.Done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .appSheetPresentationChrome()
        .accessibilityIdentifier("ExploreDiveSiteDetail.Sheet")
    }

    private var siteCoordinate: DiveCoordinate? {
        DiveMapCoordinateResolver.coordinate(from: site)
    }

    private var placeRows: [(label: String, value: String)] {
        var rows: [(label: String, value: String)] = []
        let country = site.country.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = site.region.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = site.bodyOfWater.trimmingCharacters(in: .whitespacesAndNewlines)
        if !country.isEmpty { rows.append((label: "Country", value: country)) }
        if !region.isEmpty { rows.append((label: "Region", value: region)) }
        if !body.isEmpty { rows.append((label: "Body of water", value: body)) }
        return rows
    }
}
