import Foundation

/// Re-activates dive media loading/playback after navigation, async catalog hydration, or tab changes.
enum DiveActivityMediaActivation: Sendable {

    /// Whether the pager should reaffirm its scroll target (tab active and media exists).
    nonisolated static func shouldReaffirmPagerSelection(
        isMediaContextActive: Bool,
        mediaCount: Int
    ) -> Bool {
        isMediaContextActive && mediaCount > 0
    }

    /// Resolved selection to apply after media rows become available (**`nil`** while **`photos`** is still empty or the id is absent).
    nonisolated static func resolvedPendingFocus(
        pendingMediaID: UUID?,
        in photos: [DiveMediaPhoto]
    ) -> UUID? {
        guard let pendingMediaID, !photos.isEmpty else { return nil }
        guard photos.contains(where: { $0.id == pendingMediaID }) else { return nil }
        return pendingMediaID
    }
}
