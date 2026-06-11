import Foundation

/// Copy and accessibility helpers for collapsible detail sections (buddy, site, species).
enum ExpandableDetailSectionPresentation: Sendable {

    /// Buddy detail **Dives together** — expanded logbook rows scroll inside the section; avatar header stays fixed.
    nonisolated static let buddyDetailScrollsExpandedDiveList = true

    /// Keep buddy dive rows mounted after first reveal so collapse/expand does not rebuild the list.
    nonisolated static let buddyDetailKeepsExpandedContentMounted = true

    /// Chevron only — list reveal uses no layout animation.
    nonisolated static let expandCollapseAnimationDuration: TimeInterval = 0.12

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
