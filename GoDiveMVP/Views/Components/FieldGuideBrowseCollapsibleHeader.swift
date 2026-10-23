import SwiftUI

/// Category / subcategory browse — collapsible inline title with back + add species.
struct FieldGuideBrowseCollapsibleHeader: View {
    let title: String
    let isCollapsed: Bool
    let statusBarSafeAreaTop: CGFloat
    let titleAccessibilityIdentifier: String
    /// When **`true`**, the parent provides the status-bar scrim (e.g. **`LogbookTopChromeScrim`** in category browse).
    var statusBarScrimIsProvidedExternally: Bool = true
    let onAddSpecies: () -> Void

    var body: some View {
        CollapsibleInlineTitleHeader(
            title: title,
            isCollapsed: isCollapsed,
            statusBarSafeAreaTop: statusBarSafeAreaTop,
            titleAccessibilityIdentifier: titleAccessibilityIdentifier,
            minimumTitleScaleFactor: CollapsibleInlineTitleHeaderPresentation.browseTitleMinimumScaleFactor,
            statusBarScrimIsProvidedExternally: statusBarScrimIsProvidedExternally
        ) {
            SecondaryDestinationBackButton()
        } trailing: {
            FieldGuideMarineLifeAddToolbarButton(action: onAddSpecies)
        }
    }
}
