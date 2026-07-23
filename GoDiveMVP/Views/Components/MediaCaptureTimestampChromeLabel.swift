import SwiftUI

/// Non-interactive capture timestamp chip — Liquid Glass capsule (Home dive link height).
struct MediaCaptureTimestampChromeLabel: View {
    let primaryLine: String
    let secondaryLine: String?
    var accessibilityIdentifier: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "clock.fill")
                .font(.subheadline.weight(.semibold))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(primaryLine)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let secondaryLine {
                    Text(secondaryLine)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(HomeMediaCarouselDiveLinkChromePresentation.diveNumberForeground)
                        .lineLimit(1)
                }
            }
        }
        .foregroundStyle(HomeMediaCarouselDiveLinkChromePresentation.siteTitleForeground)
        .padding(.horizontal, AppTheme.Spacing.md)
        .frame(height: HomeMediaCarouselPresentation.slideChromeControlHeight)
        .appLiquidGlassSearchFieldChrome()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var accessibilityLabel: String {
        if let secondaryLine {
            return "Captured \(primaryLine). \(secondaryLine)"
        }
        return "Captured \(primaryLine)"
    }
}
