import SwiftUI

/// Logbook tab collapsible header — **Activity Log** inline with trip / **+**.
struct LogbookCollapsibleHeader: View {
    let isCollapsed: Bool
    let statusBarSafeAreaTop: CGFloat

    var body: some View {
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
