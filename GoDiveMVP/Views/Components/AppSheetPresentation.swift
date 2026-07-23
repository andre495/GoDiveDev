import SwiftUI

/// Opaque ocean-gradient fill for Home stats and the dive overview embedded panel (map / tank / camera).
struct AppOverviewSheetPanelBackground: View {
    var body: some View {
        ZStack {
            AppTheme.Colors.surfaceElevated
            LinearGradient(
                colors: [
                    AppTheme.Colors.surfaceGradientTop.opacity(0.96),
                    AppTheme.Colors.surfaceGradientBottom,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

/// Full-bleed dimming over playing media — black scrim over **`.thinMaterial`** (Home fish overlay).
struct DiveActivityMediaFrostedOverlayBackground: View {
    var body: some View {
        Rectangle()
            .fill(.black.opacity(DiveActivityMediaFrostedOverlayPresentation.mediaScrimOpacity))
            .background {
                Rectangle()
                    .fill(.thinMaterial)
            }
    }
}

extension View {
    /// Breathing room below the sheet grabber before the first content row (modal and embedded overview).
    func appSheetContentTopSpacing() -> some View {
        padding(.top, AppTheme.Sheet.contentTopSpacing)
    }

    /// Rounded top corners + opaque blue panel fill (matches **`HomeLifetimeStatsPanel`**).
    /// When **`translucent`**, frosted **`.thinMaterial`** over the hero — always dark-mode gray
    /// (same shade in light and dark) so media stays readable underneath.
    func diveActivityOverviewEmbeddedPanelChrome(translucent: Bool = false) -> some View {
        modifier(DiveActivityOverviewEmbeddedPanelChromeModifier(translucent: translucent))
    }

    /// Standard GoDive sheet chrome: top spacing, rounded corners, frosted **`.thinMaterial`** background.
    /// Apply on any **`.sheet`** content after detent / drag-indicator modifiers (see **`.cursor/rules/swiftui-sheet-standard.mdc`**).
    func appSheetPresentationChrome() -> some View {
        appSheetContentTopSpacing()
            .presentationCornerRadius(AppTheme.Sheet.cornerRadius)
            .presentationBackground {
                Rectangle()
                    .fill(.thinMaterial)
                    .opacity(AppTheme.Sheet.backgroundMaterialOpacity)
                    .ignoresSafeArea(edges: .bottom)
            }
    }

    /// Opaque blue panel sheet chrome matching the dive overview detent background.
    /// Prefer **`diveActivityOverviewPanelModalSheetPresentation()`** for notes / buddies / tags / conditions
    /// (opens at dive **large** detent). This helper is for other blue-panel sheets that set their own detents.
    func appOverviewPanelSheetPresentationChrome() -> some View {
        presentationCornerRadius(AppTheme.Sheet.cornerRadius)
            .presentationBackground {
                AppOverviewSheetPanelBackground()
                    .ignoresSafeArea(edges: .bottom)
            }
    }
}

private struct DiveActivityOverviewEmbeddedPanelChromeModifier: ViewModifier {
    var translucent: Bool

    func body(content: Content) -> some View {
        content
            .background {
                Group {
                    if translucent {
                        DiveActivityMediaFrostedOverlayBackground()
                            .modifier(
                                DiveActivityMediaFrostedOverlayDarkAppearance(enabled: true)
                            )
                    } else {
                        AppOverviewSheetPanelBackground()
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .clipShape(
                .rect(
                    topLeadingRadius: AppTheme.Sheet.cornerRadius,
                    topTrailingRadius: AppTheme.Sheet.cornerRadius,
                    style: .continuous
                )
            )
            .shadow(color: .black.opacity(0.14), radius: 16, y: -6)
            .ignoresSafeArea(edges: .bottom)
            .modifier(DiveActivityMediaFrostedOverlayDarkAppearance(enabled: translucent))
    }
}

/// Forces dark appearance on translucent Media frost so light mode uses the same gray as dark mode.
struct DiveActivityMediaFrostedOverlayDarkAppearance: ViewModifier {
    var enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled, DiveActivityMediaFrostedOverlayPresentation.forcesDarkAppearance {
            content.environment(\.colorScheme, .dark)
        } else {
            content
        }
    }
}
