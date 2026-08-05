import SwiftUI

/// Thumbnail + name row for Field Guide **Similar species** pager.
struct FieldGuideSimilarSpeciesRow: View {
    let snapshot: MarineLifeCatalogSnapshot

    private var accent: Color {
        FieldGuideCategoryAccent.gradientTop(
            FieldGuideTaxonomy.resolvedCategoryID(for: snapshot)
        )
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            FieldGuideMarineLifeCatalogImage(
                imageURLString: snapshot.featureImageURL,
                bundleResourceName: snapshot.featureImageResourceName,
                placement: .listThumbnail(accent: accent)
            )
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.commonName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                if !snapshot.scientificName.isEmpty {
                    Text(snapshot.scientificName)
                        .font(.caption.italic())
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("FieldGuide.SpeciesDetail.SimilarSpecies.\(snapshot.uuid)")
    }
}
