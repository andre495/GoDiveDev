import SwiftUI

/// Five-star site rating for dive-site pinned headers (filled stars use accent blue).
struct DiveSitePinnedStarRatingView: View {
    let rating: Int
    var isEditable: Bool = false
    var onSelectRating: ((Int) -> Void)? = nil

    private let starCount = 5

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...starCount, id: \.self) { index in
                starButton(at: index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            DiveSitePresentation.pinnedStarRatingAccessibilityLabel(
                rating: rating,
                isEditable: isEditable
            )
        )
        .accessibilityIdentifier("DiveSite.PinnedStarRating")
    }

    @ViewBuilder
    private func starButton(at index: Int) -> some View {
        let star = Image(systemName: index <= rating ? "star.fill" : "star")
            .font(.caption)
            .foregroundStyle(
                index <= rating
                    ? AppTheme.Colors.accent
                    : AppTheme.Colors.tabUnselected.opacity(0.35)
            )
            .accessibilityHidden(true)

        if isEditable {
            Button {
                let nextRating = DiveSitePresentation.toggledStarRating(
                    current: rating,
                    selectedStar: index
                )
                onSelectRating?(nextRating)
            } label: {
                star
                    .frame(width: 16)
                    .frame(minWidth: 22, minHeight: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("DiveSite.PinnedStarRating.Star.\(index)")
        } else {
            star
                .frame(width: 16)
        }
    }
}
