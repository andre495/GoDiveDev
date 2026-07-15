import SwiftUI

enum LinkedMediaTaggedBuddiesSheetPresentation: Sendable {
    nonisolated static let columnCount = 3
    nonisolated static let gridSpacing = AppTheme.Spacing.md
    nonisolated static let avatarDiameter: CGFloat = 64
}

/// Shared chrome gate + trailing **+** for tagged species / buddies overview chrome.
enum LinkedMediaTaggedOverviewSheetPresentation: Sendable {
    nonisolated static func showsAddTagsControl(media: DiveMediaPhoto?, dive: DiveActivity?) -> Bool {
        media != nil && dive != nil
    }
}

struct LinkedMediaOverlayGlassIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .appToolbarIconButtonLabel()
        }
        .appStandaloneIconButtonStyle()
        .foregroundStyle(.white)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct LinkedMediaTaggedOverviewAddTagsButton: View {
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        LinkedMediaOverlayGlassIconButton(
            systemName: "plus",
            accessibilityLabel: accessibilityLabel,
            accessibilityIdentifier: accessibilityIdentifier,
            action: action
        )
    }
}

/// Marine-life large-detent trailing actions — Fishial **sparkles** (leading) + **+** in one capsule.
struct DiveActivityMediaLargeDetentMarineLifeTrailingActions: View {
    var showsFishialIdentifyAction: Bool
    var onIdentifyFish: (() -> Void)?
    var onAddTags: (() -> Void)?
    var addTagsAccessibilityLabel: String
    var addTagsAccessibilityIdentifier: String
    var identifyAccessibilityIdentifier: String = "DiveOverview.MediaFishialIdentify"

    private var controlHeight: CGFloat {
        AppToolbarIconButtonMetrics.tapDimension
    }

    var body: some View {
        if showsFishialIdentifyAction, let onIdentifyFish, let onAddTags {
            AppLiquidGlassIconPair(
                leadingSystemName: "sparkles",
                leadingForeground: AnyShapeStyle(
                    DiveMarineLifeTagSheetPresentation.fishialIdentifyIconGradient
                ),
                leadingAccessibilityLabel: "Identify fish with AI",
                leadingAccessibilityHint: nil,
                leadingAccessibilityIdentifier: identifyAccessibilityIdentifier,
                leadingAction: onIdentifyFish,
                trailingSystemName: "plus",
                trailingForeground: AnyShapeStyle(Color.white),
                trailingAccessibilityLabel: addTagsAccessibilityLabel,
                trailingAccessibilityHint: nil,
                trailingAccessibilityIdentifier: addTagsAccessibilityIdentifier,
                trailingAction: onAddTags
            )
        } else if let onAddTags {
            LinkedMediaTaggedOverviewAddTagsButton(
                accessibilityLabel: addTagsAccessibilityLabel,
                accessibilityIdentifier: addTagsAccessibilityIdentifier,
                action: onAddTags
            )
        } else if showsFishialIdentifyAction, let onIdentifyFish {
            Button(action: onIdentifyFish) {
                Image(systemName: "sparkles")
                    .font(AppToolbarIconButtonMetrics.glyphFont)
                    .foregroundStyle(DiveMarineLifeTagSheetPresentation.fishialIdentifyIconGradient)
                    .frame(width: controlHeight, height: controlHeight)
                    .appLiquidGlassCircleChrome()
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Identify fish with AI")
            .accessibilityIdentifier(identifyAccessibilityIdentifier)
        }
    }
}
