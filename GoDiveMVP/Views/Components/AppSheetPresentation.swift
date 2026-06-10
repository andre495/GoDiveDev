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

extension View {
    /// Breathing room below the sheet grabber before the first content row (modal and embedded overview).
    func appSheetContentTopSpacing() -> some View {
        padding(.top, AppTheme.Sheet.contentTopSpacing)
    }

    /// Rounded top corners + opaque blue panel fill (matches **`HomeLifetimeStatsPanel`**).
    func diveActivityOverviewEmbeddedPanelChrome(translucent: Bool = false) -> some View {
        background {
            Group {
                if translucent {
                    Rectangle()
                        .fill(.thinMaterial)
                        .opacity(AppTheme.Sheet.embeddedOverviewTranslucentOpacity)
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
}
