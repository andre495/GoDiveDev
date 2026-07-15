import SwiftUI

/// Shared Home-style dive open chip — book icon, site title, **`#` · trip** subtitle on Liquid Glass.
struct MediaDiveLinkChromeButton: View {
    let siteDisplayName: String
    let diveNumberLabel: String
    let linkedTripTitle: String?
    let action: () -> Void
    var accessibilityIdentifier: String = "Home.MediaCarousel.OpenDive"

    /// Bumps after navigation starts so SwiftUI can fire haptic without blocking the push.
    @State private var openDiveHapticTick = 0

    private var title: String {
        let site = siteDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return site.isEmpty ? "New Dive" : site
    }

    private var subtitleLine: String? {
        HomeMediaCarouselDiveLinkChromePresentation.diveLinkSubtitle(
            diveNumberLabel: diveNumberLabel,
            linkedTripTitle: linkedTripTitle
        )
    }

    var body: some View {
        Button {
            // Navigate first — unprepared UIKit impact generators can stall the main actor.
            action()
            guard HomeMediaCarouselDiveLinkChromePresentation.shouldPlayOpenDiveHaptic() else { return }
            openDiveHapticTick &+= 1
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "book.closed.fill")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if let subtitleLine {
                        Text(subtitleLine)
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
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: openDiveHapticTick)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var accessibilityLabel: String {
        var parts = ["Open dive at \(title)"]
        if let subtitleLine {
            parts.append(subtitleLine)
        }
        return parts.joined(separator: ", ")
    }
}
