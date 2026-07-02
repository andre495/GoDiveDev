import SwiftUI

/// Field Guide hub top bar — **Field Guide** title inline with add-species **+**.
struct FieldGuideTopChrome: View {
    let isCollapsed: Bool
    let statusBarSafeAreaTop: CGFloat
    let onAddSpecies: () -> Void

    var body: some View {
        CollapsibleInlineTitleHeader(
            title: FieldGuideHubPresentation.tabTitle,
            isCollapsed: isCollapsed,
            statusBarSafeAreaTop: statusBarSafeAreaTop,
            titleAccessibilityIdentifier: FieldGuideHubPresentation.titleAccessibilityIdentifier
        ) {
            Color.clear.accessibilityHidden(true)
        } trailing: {
            FieldGuideMarineLifeAddToolbarButton(action: onAddSpecies)
        }
    }
}
