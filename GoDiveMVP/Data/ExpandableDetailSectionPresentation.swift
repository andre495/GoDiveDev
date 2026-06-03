import Foundation

/// Copy and accessibility helpers for collapsible detail sections (buddy, site, species).
enum ExpandableDetailSectionPresentation: Sendable {

    nonisolated static func showsExpandControl(itemCount: Int) -> Bool {
        itemCount > 0
    }

    nonisolated static func headerAccessibilityLabel(
        title: String,
        itemCount: Int,
        isExpanded: Bool
    ) -> String {
        guard itemCount > 0 else { return title }
        let state = isExpanded ? "expanded" : "collapsed"
        let countLabel = itemCount == 1 ? "1 item" : "\(itemCount) items"
        return "\(title), \(countLabel), \(state)"
    }
}
