import SwiftUI

/// Shared dive-site metadata blocks for catalog + OpenDiveMap detail screens.
struct ExploreDiveSiteDetailMetadataView: View {
    let record: DiveSiteDisplayRecord
    var hiddenDetailLabels: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            detailSection(title: "Location") {
                detailRow(title: "Coordinates", value: record.coordinateLine)
            }

            detailSection(title: "Place") {
                ForEach(record.placeDetailRows, id: \.label) { row in
                    detailRow(title: row.label, value: row.value)
                }
            }

            detailSection(title: "Details") {
                ForEach(record.filteredDetailRows(hiding: hiddenDetailLabels), id: \.label) { row in
                    detailRow(title: row.label, value: row.value)
                }
            }
        }
    }

    @ViewBuilder
    private func detailSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            content()
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer(minLength: AppTheme.Spacing.sm)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }
}
