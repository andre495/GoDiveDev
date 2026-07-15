import SwiftUI

/// Right-aligned white section title used by multi-category search results and **Search → Media** month dividers.
struct GlobalSearchResultsSectionHeader: View {
    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Color.clear
                .frame(
                    width: GlobalSearchPresentation.ResultsSectionHeaderPresentation.backButtonReservedWidth()
                )
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            Text(title)
                .font(
                    .system(
                        size: GlobalSearchPresentation.ResultsSectionHeaderPresentation.titleFontSize,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)
                .textCase(nil)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, GlobalSearchPresentation.ResultsSectionHeaderPresentation.horizontalPadding)
        .padding(.vertical, GlobalSearchPresentation.ResultsSectionHeaderPresentation.verticalPadding)
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(.isHeader)
    }
}
