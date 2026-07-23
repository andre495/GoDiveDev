import SwiftUI

/// Logbook tab collapsible header — **Activity Log** inline with trip / **+**, feed scope toggle, and My Activities summary.
struct LogbookCollapsibleHeader: View {
    @Binding var feedScope: LogbookFeedScope
    @Binding var myActivitiesKindFilter: LogbookMyActivitiesKindFilter
    let isCollapsed: Bool
    let showsFeedScopeToggle: Bool
    let showsMyActivitiesSummary: Bool
    let isMyActivitiesSummaryLoading: Bool
    let myActivitiesSummary: LogbookMyActivitiesSummary
    let statusBarSafeAreaTop: CGFloat

    private var showsExpandedChromeBelowTitle: Bool {
        !isCollapsed && (showsFeedScopeToggle || showsMyActivitiesSummary)
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

            HStack(spacing: AppTheme.Spacing.sm) {
                Spacer(minLength: 0)
                HStack(spacing: AppTheme.Spacing.sm) {
                    LogbookFeedScopeToggle(selection: $feedScope)
                    if feedScope == .myActivities {
                        LogbookMyActivitiesKindFilterMenu(selection: $myActivitiesKindFilter)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .opacity(showsFeedScopeToggle ? 1 : 0)
            .frame(maxHeight: showsFeedScopeToggle ? nil : 0)
            .clipped()
            .allowsHitTesting(showsFeedScopeToggle)
            .accessibilityHidden(!showsFeedScopeToggle)

            if showsMyActivitiesSummary {
                Group {
                    if isMyActivitiesSummaryLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .accessibilityIdentifier(
                                LogbookMyActivitiesSummaryPresentation.loadingAccessibilityIdentifier
                            )
                    } else {
                        Text(LogbookMyActivitiesSummaryPresentation.headerLine(for: myActivitiesSummary))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .accessibilityIdentifier(
                                LogbookCollapsibleHeaderPresentation.myActivitiesSummaryAccessibilityIdentifier
                            )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .opacity(showsExpandedChromeBelowTitle ? 1 : 0)
                .frame(maxHeight: showsExpandedChromeBelowTitle ? nil : 0)
                .clipped()
                .allowsHitTesting(false)
                .accessibilityHidden(!showsExpandedChromeBelowTitle)
            }
        }
        .animation(.snappy(duration: 0.18), value: showsFeedScopeToggle)
        .animation(.snappy(duration: 0.18), value: showsMyActivitiesSummary)
        .animation(.snappy(duration: 0.18), value: isMyActivitiesSummaryLoading)
        .animation(.snappy(duration: 0.18), value: isCollapsed)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: AppHeaderMetrics.HeightKey.self, value: proxy.size.height)
            }
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
