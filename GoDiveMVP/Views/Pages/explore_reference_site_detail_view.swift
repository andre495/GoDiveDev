import SwiftUI

/// Read-only OpenDiveMap reference site pushed from **Explore** (all-sites scope).
struct ExploreReferenceSiteDetailView: View {
    let snapshot: DiveSiteReferenceSnapshot

    var body: some View {
        AppPage(title: DiveSiteCatalogMatcher.sanitizedReferenceDisplayName(snapshot.name) ?? snapshot.name, titleUsesBrandForeground: true) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                if let coordinateLine {
                    detailSection(title: "Coordinates") {
                        Text(coordinateLine)
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                }

                if let placeLine {
                    detailSection(title: "Place") {
                        Text(placeLine)
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                }

                if let maxDepthMeters = snapshot.maxDepthMeters {
                    detailSection(title: "Max depth") {
                        Text("\(maxDepthMeters) m")
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                }

                if !snapshot.entry.isEmpty {
                    detailSection(title: "Entry") {
                        Text(snapshot.entry.capitalized)
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                }

                if !snapshot.topologies.isEmpty {
                    detailSection(title: "Site type") {
                        Text(snapshot.topologies.map { $0.replacingOccurrences(of: "_", with: " ") }.joined(separator: ", "))
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                }

                Text("OpenDiveMap reference site. Log a dive here to add it to your catalog.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding(.top, AppTheme.Spacing.sm)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.lg)
        }
        .accessibilityIdentifier("Explore.ReferenceSiteDetail.Root")
    }

    private var coordinateLine: String? {
        guard let lat = snapshot.latitude, let lon = snapshot.longitude else { return nil }
        let coordinate = DiveCoordinate(latitude: lat, longitude: lon)
        guard DiveMapCoordinateResolver.isUsable(coordinate) else { return nil }
        return DiveLocationMapPresentation.coordinateLabel(for: coordinate)
    }

    private var placeLine: String? {
        let line = ExploreDiveSiteListDisplay.cityCountryLine(
            country: snapshot.country,
            region: snapshot.seaName
        )
        return line.isEmpty ? nil : line
    }

    @ViewBuilder
    private func detailSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            content()
        }
    }
}
