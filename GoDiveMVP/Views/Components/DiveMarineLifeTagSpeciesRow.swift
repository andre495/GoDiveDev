import SwiftUI

/// Species row for dive media tag sheets — catalog thumbnail + name/detail.
struct DiveMarineLifeTagSpeciesRow: View, Equatable {
    let commonName: String
    let trailingLabel: String
    let detailLine: String
    let featureImageURL: String
    let featureImageResourceName: String
    var showsTaggedCheckmark = false

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            FieldGuideMarineLifeCatalogImage(
                imageURLString: featureImageURL,
                bundleResourceName: featureImageResourceName,
                placement: .mediaSheetHero(
                    height: MarineLifeMediaTagPresentation.speciesRowThumbnailHeight,
                    cornerRadius: 8
                )
            )
            .frame(
                width: MarineLifeMediaTagPresentation.speciesRowThumbnailWidth,
                height: MarineLifeMediaTagPresentation.speciesRowThumbnailHeight
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                    Text(commonName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: AppTheme.Spacing.sm)

                    Text(trailingLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Text(detailLine)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsTaggedCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Colors.accent)
                    .accessibilityHidden(true)
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
    }
}
