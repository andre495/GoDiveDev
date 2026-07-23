import SwiftUI

/// Fullscreen media chrome — bottom Home-style dive link + buddy/fish capsule pair.
/// Top **X** (leading) and plain **#/#** (trailing) live in **`LinkedMediaFullscreenView`**.
struct TripDetailMediaGalleryOverlayControls: View {
    enum BottomLeadingChrome: Sendable {
        case diveLink(
            siteDisplayName: String,
            diveNumberLabel: String,
            linkedTripTitle: String?,
            onOpenOnDive: () -> Void
        )
        case captureTimestamp(primaryLine: String, secondaryLine: String?)
    }

    let bottomLeadingChrome: BottomLeadingChrome
    let isFeatured: Bool
    /// When true, shows buddy + fish in one Liquid Glass capsule.
    var showsMediaTagButtons: Bool = true
    var hasBuddyTags: Bool = false
    var hasMarineLifeTags: Bool = false
    var onToggleFeatured: (() -> Void)?
    var onToggleMarineLife: (() -> Void)?
    var onToggleBuddy: (() -> Void)?
    var featuredStarPlacement: TripDetailMediaGalleryFeaturedStarPlacement = .bottomTrailing
    /// Top padding for **`.topTrailing`** star (safe area + chrome row — set by host **`GeometryReader`**).
    var featuredStarTopInset: CGFloat = 0
    var featureToggleAccessibilityIdentifier = "TripDetail.Media.FeatureToggle"
    var openOnDiveAccessibilityIdentifier = "TripDetail.Media.OpenOnDive"
    var marineLifeAccessibilityIdentifier = "TripDetail.Media.MarineLifeTag"
    var buddyAccessibilityIdentifier = "TripDetail.Media.BuddyTag"
    var captureTimestampAccessibilityIdentifier = "TripDetail.Media.CaptureTimestamp"

    private var chromeControlHeight: CGFloat {
        LinkedMediaFullscreenPresentation.topChromeControlHeight
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                    .allowsHitTesting(false)

                bottomChromeRow
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            if showsFeaturedStarInTopTrailing {
                featureStarButton
                    .padding(.trailing, AppTheme.Spacing.md)
                    .padding(.top, featuredStarTopInset)
            }
        }
    }

    private var bottomChromeRow: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.md) {
            bottomLeadingControl

            Spacer(minLength: AppTheme.Spacing.sm)

            trailingControls
        }
    }

    @ViewBuilder
    private var bottomLeadingControl: some View {
        switch bottomLeadingChrome {
        case let .diveLink(siteDisplayName, diveNumberLabel, linkedTripTitle, onOpenOnDive):
            MediaDiveLinkChromeButton(
                siteDisplayName: siteDisplayName,
                diveNumberLabel: diveNumberLabel,
                linkedTripTitle: linkedTripTitle,
                action: onOpenOnDive,
                accessibilityIdentifier: openOnDiveAccessibilityIdentifier
            )
        case let .captureTimestamp(primaryLine, secondaryLine):
            MediaCaptureTimestampChromeLabel(
                primaryLine: primaryLine,
                secondaryLine: secondaryLine,
                accessibilityIdentifier: captureTimestampAccessibilityIdentifier
            )
        }
    }

    @ViewBuilder
    private var trailingControls: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            if showsFeaturedStarInBottomTrailing {
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

    private var showsFeaturedStarInBottomTrailing: Bool {
        onToggleFeatured != nil && featuredStarPlacement == .bottomTrailing
    }

    private var showsFeaturedStarInTopTrailing: Bool {
        onToggleFeatured != nil && featuredStarPlacement == .topTrailing
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
