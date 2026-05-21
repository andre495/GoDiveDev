import SwiftUI

/// Compact summary when the **Media** overview panel is minimized.
struct DiveActivityPhotosCollapsedSummary: View {
    let dateText: String
    let titleText: String
    let mediaCountText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleText)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text(dateText)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.tabUnselected)

            Text(mediaCountText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(titleText), \(dateText), \(mediaCountText)")
    }
}
