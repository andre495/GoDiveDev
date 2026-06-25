import SwiftUI

/// Shared Liquid Glass chrome for toolbar buttons, search fields, and segmented pickers.
///
/// Follows [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass):
/// **`.glass`** buttons, standard **`.segmented`** pickers, **`glassEffect`** on custom search capsules and media-overlay circles,
/// and **`GlassEffectContainer`** for adjacent controls.
enum AppButtonChrome {
    /// Matches **`AppTheme.Layout.glassChromeControlHeight`** (search capsules + toolbar glass controls).
    static var standaloneIconMinTapDimension: CGFloat {
        AppTheme.Layout.glassChromeControlHeight
    }
}

/// Shared glyph + tap target for circular Liquid Glass toolbar icon buttons (Field Guide **+** reference).
enum AppToolbarIconButtonMetrics {
    static let tapDimension: CGFloat = AppTheme.Layout.glassChromeControlHeight
    static let glyphFont: Font = .title3.weight(.semibold)
}

private struct AppGlassButtonStyleModifier: ViewModifier {
    let isCircularIcon: Bool
    var tapDimension: CGFloat = AppToolbarIconButtonMetrics.tapDimension

    func body(content: Content) -> some View {
        let styled = content
            .buttonStyle(.glass)
            .controlSize(.regular)

        if isCircularIcon {
            styled
                .buttonBorderShape(.circle)
                .frame(width: tapDimension, height: tapDimension)
                .fixedSize()
        } else {
            styled.frame(height: tapDimension)
        }
    }
}

private struct AppSegmentedControlStyleModifier: ViewModifier {
    let showsTextLabels: Bool

    func body(content: Content) -> some View {
        if showsTextLabels {
            content.pickerStyle(.segmented)
        } else {
            content.pickerStyle(.segmented).labelsHidden()
        }
    }
}

extension View {
    /// System Liquid Glass circular toolbar icon button (**`CatalogSearchField`** height).
    func appStandaloneIconButtonStyle(
        tapDimension: CGFloat = AppToolbarIconButtonMetrics.tapDimension
    ) -> some View {
        modifier(AppGlassButtonStyleModifier(isCircularIcon: true, tapDimension: tapDimension))
    }

    /// Liquid Glass toolbar text button (**Edit**) — same height as search capsules, intrinsic width.
    func appGlassToolbarTextButtonStyle() -> some View {
        modifier(AppGlassButtonStyleModifier(isCircularIcon: false))
    }

    /// Liquid Glass capsule behind inline list / map search fields.
    func appLiquidGlassSearchFieldChrome() -> some View {
        glassEffect(.regular.interactive(), in: .capsule)
    }

    /// Liquid Glass circle for compact icon chips on media overlays and carousel chrome.
    func appLiquidGlassCircleChrome() -> some View {
        glassEffect(.regular.interactive(), in: .circle)
    }

    /// Standard **UISegmentedControl** (Liquid Glass on iOS 26+). Use **`showsTextLabels: true`** for icon + title segments.
    func appSegmentedControlStyle(showsTextLabels: Bool = false) -> some View {
        modifier(AppSegmentedControlStyleModifier(showsTextLabels: showsTextLabels))
    }

    /// Groups neighboring glass controls for correct sampling and morphing.
    func appLiquidGlassChromeContainer() -> some View {
        GlassEffectContainer {
            self
        }
    }

    /// Fixed row height for search + neighboring glass controls in top chrome.
    func appGlassChromeControlRowHeight() -> some View {
        frame(height: AppTheme.Layout.glassChromeControlHeight)
    }

    /// **`.title3`** glyph centered in a circular glass button (**Field Guide** **+** reference).
    func appToolbarIconButtonLabel() -> some View {
        font(AppToolbarIconButtonMetrics.glyphFont)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
    }
}

/// Liquid Glass **Edit** label for page / detail toolbars (not dive overview field-section ellipsis).
struct AppEditToolbarButton: View {
    let action: () -> Void
    let accessibilityIdentifier: String
    var title: String = "Edit"
    var accessibilityLabel: String?

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .padding(.horizontal, AppTheme.Spacing.sm)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .appGlassToolbarTextButtonStyle()
        .foregroundStyle(AppTheme.Colors.tabSelected)
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

/// Liquid Glass circular toolbar icon (**share**, **settings**, **+**, etc.).
struct AppToolbarIconButton: View {
    let systemImage: String
    let action: () -> Void
    let accessibilityIdentifier: String
    let accessibilityLabel: String
    var isEnabled: Bool = true
    var foregroundStyle: Color = AppTheme.Colors.iconPrimary

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .appToolbarIconButtonLabel()
        }
        .appStandaloneIconButtonStyle()
        .foregroundStyle(foregroundStyle)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
