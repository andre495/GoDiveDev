import SwiftUI

/// Logbook tab collapsible header — **Activity Log** inline with trip / **+** and feed scope toggle.
struct LogbookCollapsibleHeader: View {
    @Binding var feedScope: LogbookFeedScope
    @Binding var myActivitiesKindFilter: LogbookMyActivitiesKindFilter
    let isCollapsed: Bool
    let showsFeedScopeToggle: Bool
    let statusBarSafeAreaTop: CGFloat

    private var showsExpandedChromeBelowTitle: Bool {
        !isCollapsed && showsFeedScopeToggle
    }

    var body: some View {
        VStack(spacing: showsExpandedChromeBelowTitle ? AppTheme.Spacing.sm : 0) {
            CollapsibleInlineTitleHeader(
                title: LogbookCollapsibleHeaderPresentation.title,
                isCollapsed: isCollapsed,
                statusBarSafeAreaTop: statusBarSafeAreaTop,
                titleAccessibilityIdentifier: LogbookCollapsibleHeaderPresentation.titleAccessibilityIdentifier
            ) {
                logbookTripPlannerButton
            } trailing: {
                logbookAddActivityButton
            }

            // Explore-style chrome: centered toggle + trailing filter as siblings in a
            // GlassEffectContainer (do not stretch the toggle with maxWidth — that left a
            // full-width dark glass band). Row height matches the 44pt filter so glass is not clipped.
            feedScopeChromeRow
                .opacity(showsFeedScopeToggle ? 1 : 0)
                .frame(
                    maxHeight: showsFeedScopeToggle
                        ? LogbookFeedScopeTogglePresentation.chromeRowHeight
                        : 0
                )
                // No `.clipped()` — it shaved the 44pt filter glass (toggle shell is ~40pt tall)
                // and cut Liquid Glass soft edges. Opacity hides the row when collapsed.
                .allowsHitTesting(showsFeedScopeToggle)
                .accessibilityHidden(!showsFeedScopeToggle)
        }
        .animation(.snappy(duration: 0.18), value: showsFeedScopeToggle)
        .animation(.snappy(duration: 0.18), value: isCollapsed)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: AppHeaderMetrics.HeightKey.self, value: proxy.size.height)
            }
        }
    }

    /// Matches **`ExploreTopChrome`**: discrete glass controls in a **`ZStack`**, not an overlay on a stretched toggle.
    private var feedScopeChromeRow: some View {
        GlassEffectContainer {
            ZStack {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    LogbookMyActivitiesKindFilterMenu(selection: $myActivitiesKindFilter)
                        .opacity(feedScope == .myActivities ? 1 : 0)
                        .allowsHitTesting(feedScope == .myActivities)
                        .accessibilityHidden(feedScope != .myActivities)
                }
                .padding(.trailing, AppTheme.Spacing.lg)

                LogbookFeedScopeToggle(selection: $feedScope)
            }
            .appGlassChromeControlRowHeight()
        }
    }

    private var logbookTripPlannerButton: some View {
        NavigationLink(value: LogbookRoute.tripPlanner) {
            Image(systemName: TripPlannerPresentation.exploreChromeSystemImage)
                .appToolbarIconButtonLabel()
        }
        .appStandaloneIconButtonStyle()
        .accessibilityLabel(TripPlannerPresentation.exploreChromeAccessibilityLabel)
        .accessibilityIdentifier("Logbook.TripPlanner")
    }

    private var logbookAddActivityButton: some View {
        NavigationLink(value: LogbookRoute.addActivity) {
            Image(systemName: "plus")
                .appToolbarIconButtonLabel()
        }
        .appStandaloneIconButtonStyle()
        .accessibilityLabel("Add activity")
        .accessibilityIdentifier("Logbook.AddActivity")
    }
}
