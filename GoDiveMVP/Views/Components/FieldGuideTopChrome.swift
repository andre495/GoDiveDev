import SwiftUI

/// Field Guide hub top bar — **Field Guide** title inline with add-species **+**.
struct FieldGuideTopChrome: View {
    let isCollapsed: Bool
    let statusBarSafeAreaTop: CGFloat
    /// When **`true`**, the parent provides the status-bar scrim (e.g. **`LogbookTopChromeScrim`** in Field Guide hub).
    var statusBarScrimIsProvidedExternally: Bool = true
    let onAddSpecies: () -> Void

    var body: some View {
        CollapsibleInlineTitleHeader(
            title: FieldGuideHubPresentation.tabTitle,
            isCollapsed: isCollapsed,
            statusBarSafeAreaTop: statusBarSafeAreaTop,
            titleAccessibilityIdentifier: FieldGuideHubPresentation.titleAccessibilityIdentifier,
            statusBarScrimIsProvidedExternally: statusBarScrimIsProvidedExternally
        ) {
            Color.clear.accessibilityHidden(true)
        } trailing: {
            FieldGuideMarineLifeAddToolbarButton(action: onAddSpecies)
        }
    }
}
