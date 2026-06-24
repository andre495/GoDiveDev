import SwiftUI

/// Pinned title block on catalog + reference dive-site detail (**FieldGuideBlueSheetPage**).
struct ExploreDiveSiteDetailPinnedTitleView: View {
    let record: DiveSiteDisplayRecord
    let starRating: Int
    let isStarRatingEditable: Bool
    let onStarRatingSelected: ((Int) -> Void)?
    let accessibilityIdentifier: String

    init(
        record: DiveSiteDisplayRecord,
        starRating: Int? = nil,
        isStarRatingEditable: Bool = false,
        onStarRatingSelected: ((Int) -> Void)? = nil,
        accessibilityIdentifier: String
    ) {
        self.record = record
        self.starRating = starRating ?? record.pinnedStarRating
        self.isStarRatingEditable = isStarRatingEditable
        self.onStarRatingSelected = onStarRatingSelected
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                DiveSitePinnedStarRatingView(
                    rating: starRating,
                    isEditable: isStarRatingEditable,
                    onSelectRating: onStarRatingSelected
                )
                .accessibilityIdentifier("\(accessibilityIdentifier).StarRating")

                Spacer(minLength: AppTheme.Spacing.sm)

                Text(record.pinnedDiveCountLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .accessibilityIdentifier("\(accessibilityIdentifier).DiveCount")
            }

            Text(record.displayName)
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)

            if let locationLine = record.pinnedLocationLine {
                Text(locationLine)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("\(accessibilityIdentifier).Location")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
