import SwiftUI

/// Two icon actions inside one Liquid Glass **capsule** (not separate circles).
struct AppLiquidGlassIconPair: View {
    let leadingSystemName: String
    let leadingForeground: AnyShapeStyle
    let leadingAccessibilityLabel: String
    let leadingAccessibilityHint: String?
    let leadingAccessibilityIdentifier: String
    let leadingAction: () -> Void

    let trailingSystemName: String
    let trailingForeground: AnyShapeStyle
    let trailingAccessibilityLabel: String
    let trailingAccessibilityHint: String?
    let trailingAccessibilityIdentifier: String
    let trailingAction: () -> Void

    /// Capsule height — playback chrome uses dive-chip height; toolbar pairs stay **44**.
    var controlHeight: CGFloat = AppToolbarIconButtonMetrics.tapDimension

    var body: some View {
        HStack(spacing: 0) {
            iconButton(
                systemName: leadingSystemName,
                foreground: leadingForeground,
                accessibilityLabel: leadingAccessibilityLabel,
                accessibilityHint: leadingAccessibilityHint,
                accessibilityIdentifier: leadingAccessibilityIdentifier,
                action: leadingAction
            )

            iconButton(
                systemName: trailingSystemName,
                foreground: trailingForeground,
                accessibilityLabel: trailingAccessibilityLabel,
                accessibilityHint: trailingAccessibilityHint,
                accessibilityIdentifier: trailingAccessibilityIdentifier,
                action: trailingAction
            )
        }
        .padding(.horizontal, 4)
        .frame(height: controlHeight)
        .appLiquidGlassSearchFieldChrome()
    }

    private func iconButton(
        systemName: String,
        foreground: AnyShapeStyle,
        accessibilityLabel: String,
        accessibilityHint: String?,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(AppToolbarIconButtonMetrics.glyphFont)
                .foregroundStyle(foreground)
                .frame(width: controlHeight, height: controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
        .modifier(OptionalAccessibilityHint(hint: accessibilityHint))
    }
}

private struct OptionalAccessibilityHint: ViewModifier {
    let hint: String?

    func body(content: Content) -> some View {
        if let hint, !hint.isEmpty {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

extension AppLiquidGlassIconPair {
    /// Buddy + fish playback chrome.
    static func mediaTagControls(
        hasBuddyTags: Bool,
        hasMarineLifeTags: Bool,
        buddyAccessibilityIdentifier: String,
        marineLifeAccessibilityIdentifier: String,
        onToggleBuddy: @escaping () -> Void,
        onToggleMarineLife: @escaping () -> Void
    ) -> AppLiquidGlassIconPair {
        AppLiquidGlassIconPair(
            leadingSystemName: "person.2.fill",
            leadingForeground: AnyShapeStyle(
                LinkedMediaFullscreenPresentation.isMediaTagControlActive(hasTags: hasBuddyTags)
                    ? AppTheme.Colors.accent
                    : Color.white
            ),
            leadingAccessibilityLabel: "Buddies",
            leadingAccessibilityHint: "Tag buddies on this photo or video",
            leadingAccessibilityIdentifier: buddyAccessibilityIdentifier,
            leadingAction: onToggleBuddy,
            trailingSystemName: "fish.fill",
            trailingForeground: AnyShapeStyle(
                LinkedMediaFullscreenPresentation.isMediaTagControlActive(hasTags: hasMarineLifeTags)
                    ? AppTheme.Colors.accent
                    : Color.white
            ),
            trailingAccessibilityLabel: "Marine life",
            trailingAccessibilityHint: "Tag marine life on this photo or video",
            trailingAccessibilityIdentifier: marineLifeAccessibilityIdentifier,
            trailingAction: onToggleMarineLife,
            controlHeight: HomeMediaCarouselPresentation.slideChromeControlHeight
        )
    }
}
