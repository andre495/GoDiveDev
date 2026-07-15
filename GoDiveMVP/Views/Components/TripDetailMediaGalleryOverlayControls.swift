import SwiftUI

/// Fullscreen media chrome — bottom Home-style dive link + buddy/fish capsule pair.
/// Top **X** (leading) and plain **#/#** (trailing) live in **`LinkedMediaFullscreenView`**.
struct TripDetailMediaGalleryOverlayControls: View {
    let siteDisplayName: String
    let diveNumberLabel: String
    let linkedTripTitle: String?
    let isFeatured: Bool
    /// When true, shows buddy + fish in one Liquid Glass capsule.
    var showsMediaTagButtons: Bool = true
    var hasBuddyTags: Bool = false
    var hasMarineLifeTags: Bool = false
    let onOpenOnDive: () -> Void
    var onToggleFeatured: (() -> Void)?
    var onToggleMarineLife: (() -> Void)?
    var onToggleBuddy: (() -> Void)?
    var featureToggleAccessibilityIdentifier = "TripDetail.Media.FeatureToggle"
    var openOnDiveAccessibilityIdentifier = "TripDetail.Media.OpenOnDive"
    var marineLifeAccessibilityIdentifier = "TripDetail.Media.MarineLifeTag"
    var buddyAccessibilityIdentifier = "TripDetail.Media.BuddyTag"

    private var chromeControlHeight: CGFloat {
        LinkedMediaFullscreenPresentation.topChromeControlHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
                .allowsHitTesting(false)

            bottomChromeRow
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var bottomChromeRow: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.md) {
            MediaDiveLinkChromeButton(
                siteDisplayName: siteDisplayName,
                diveNumberLabel: diveNumberLabel,
                linkedTripTitle: linkedTripTitle,
                action: onOpenOnDive,
                accessibilityIdentifier: openOnDiveAccessibilityIdentifier
            )

            Spacer(minLength: AppTheme.Spacing.sm)

            trailingControls
        }
    }

    @ViewBuilder
    private var trailingControls: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            if onToggleFeatured != nil {
                featureStarButton
            }

            if showsMediaTagButtons, let onToggleBuddy, let onToggleMarineLife {
                AppLiquidGlassIconPair.mediaTagControls(
                    hasBuddyTags: hasBuddyTags,
                    hasMarineLifeTags: hasMarineLifeTags,
                    buddyAccessibilityIdentifier: buddyAccessibilityIdentifier,
                    marineLifeAccessibilityIdentifier: marineLifeAccessibilityIdentifier,
                    onToggleBuddy: onToggleBuddy,
                    onToggleMarineLife: onToggleMarineLife
                )
            }
        }
    }

    private var featureStarButton: some View {
        Button(action: { onToggleFeatured?() }) {
            Image(systemName: isFeatured ? "star.fill" : "star")
                .font(AppToolbarIconButtonMetrics.glyphFont)
                .foregroundStyle(isFeatured ? AppTheme.Colors.accent : .white)
                .frame(width: chromeControlHeight, height: chromeControlHeight)
                .appLiquidGlassCircleChrome()
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFeatured ? "Featured buddy media" : "Feature on buddy header")
        .accessibilityHint(
            isFeatured
                ? "Removes this as the buddy header media and uses a random tagged item instead."
                : "Shows this photo or video on the buddy header. Only one item can be featured."
        )
        .accessibilityIdentifier(featureToggleAccessibilityIdentifier)
    }
}
