import Foundation

/// Dive overview **Buddies** section — map tab avatar strip.
enum DiveActivityBuddiesOverviewPresentation: Sendable {

    /// **`true`** when tapping an avatar should push buddy or friend profile detail.
    nonisolated static func shouldOpenBuddyDetail(
        buddy: DiveBuddy?,
        owner: UserProfile?
    ) -> Bool {
        guard let buddy else { return false }
        return !DiveBuddySelfRepresentation.isSelfBuddy(buddy, owner: owner)
    }
}
