import SwiftUI

/// Category / subcategory browse — collapsible inline title with back + add species.
struct FieldGuideBrowseCollapsibleHeader: View {
    let title: String
    let isCollapsed: Bool
    let statusBarSafeAreaTop: CGFloat
    let titleAccessibilityIdentifier: String
    let onAddSpecies: () -> Void

    var body: some View {
        CollapsibleInlineTitleHeader(
            title: title,
            isCollapsed: isCollapsed,
            statusBarSafeAreaTop: statusBarSafeAreaTop,
            titleAccessibilityIdentifier: titleAccessibilityIdentifier,
            minimumTitleScaleFactor: CollapsibleInlineTitleHeaderPresentation.browseTitleMinimumScaleFactor
        ) {
            SecondaryDestinationBackButton()
        } trailing: {
            FieldGuideMarineLifeAddToolbarButton(action: onAddSpecies)
        }
    }
}
