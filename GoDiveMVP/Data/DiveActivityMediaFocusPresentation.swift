import Foundation

/// Deep-link target when a dive is opened from a logbook row thumbnail or Home featured media:
/// the **Media** tab, at the **medium** detent, focused on the tapped photo in the carousel.
enum DiveActivityMediaFocusPresentation {
    struct Focus: Equatable, Sendable {
        let tab: DiveActivityTab
        let detent: DiveActivityOverviewDetent
        let mediaID: UUID
    }

    /// **`nil`** when there is no media to focus (so the dive opens with its default tab/detent).
    static func focus(forMediaFocusID mediaFocusID: UUID?) -> Focus? {
        guard let mediaFocusID else { return nil }
        return Focus(tab: .camera, detent: .medium, mediaID: mediaFocusID)
    }
}
