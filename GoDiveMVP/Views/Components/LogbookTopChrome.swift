import SwiftUI

/// Logbook top bar — trip planner leading action + trailing toolbar actions (no inline search).
struct LogbookToolbarChrome<TrailingActions: View>: View {
    @ViewBuilder let trailingActions: () -> TrailingActions

    var body: some View {
        GlassEffectContainer {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                NavigationLink(value: LogbookRoute.tripPlanner) {
                    Image(systemName: TripPlannerPresentation.exploreChromeSystemImage)
                        .appToolbarIconButtonLabel()
                }
                .appStandaloneIconButtonStyle()
                .foregroundStyle(AppTheme.Colors.iconPrimary)
                .accessibilityLabel(TripPlannerPresentation.exploreChromeAccessibilityLabel)
                .accessibilityIdentifier("Logbook.TripPlanner")

                Spacer(minLength: 0)

                trailingActions()
            }
            .appGlassChromeControlRowHeight()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .appTopChromeVerticalPadding()
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: AppHeaderMetrics.HeightKey.self, value: proxy.size.height)
            }
        }
    }
}
