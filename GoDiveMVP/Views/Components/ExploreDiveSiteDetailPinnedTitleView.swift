import SwiftUI

/// Pinned title block on catalog + reference dive-site detail (**`BlueSheetDetailPage`**).
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
        BlueSheetPinnedSummary(
            title: record.displayName,
            titleAccessibilityIdentifier: "\(accessibilityIdentifier).Title",
            subtitle: record.pinnedLocationLine,
            subtitleAccessibilityIdentifier: record.pinnedLocationLine == nil
                ? nil
                : "\(accessibilityIdentifier).Location",
            accessibilityIdentifier: accessibilityIdentifier,
            topRow: {
                diveSiteRatingRow
            }
        )
    }

    @ViewBuilder
    private var diveSiteRatingRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            DiveSitePinnedStarRatingView(
                rating: starRating,
                isEditable: isStarRatingEditable,
                onSelectRating: onStarRatingSelected
            )
            .accessibilityIdentifier("\(accessibilityIdentifier).StarRating")

            Spacer(minLength: AppTheme.Spacing.sm)

            Text(record.pinnedDiveCountLabel)
                .font(BlueSheetPinnedSummaryPresentation.accentMediumFont)
                .foregroundStyle(AppTheme.Colors.accent)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .accessibilityIdentifier("\(accessibilityIdentifier).DiveCount")
        }
    }
}
