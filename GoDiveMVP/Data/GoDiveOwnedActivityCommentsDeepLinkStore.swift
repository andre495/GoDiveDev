import Foundation

/// One-shot flag: open the comments sheet after navigating to an **owned** activity
/// (comment push tap). Consumed when Logbook builds the detail destination.
@MainActor
final class GoDiveOwnedActivityCommentsDeepLinkStore {
    static let shared = GoDiveOwnedActivityCommentsDeepLinkStore()

    private var pendingActivityID: UUID?

    private init() {}

    func setPending(activityID: UUID) {
        pendingActivityID = activityID
    }

    /// Returns `true` once when `activityID` matches the pending comment deep link.
    func consume(activityID: UUID) -> Bool {
        guard pendingActivityID == activityID else { return false }
        pendingActivityID = nil
        return true
    }

    func clear() {
        pendingActivityID = nil
    }
}

enum GoDiveOwnedActivityCommentsDeepLinkPresentation: Sendable {
    /// Comment-notification taps should open the owned activity with the comments sheet.
    nonisolated static let opensCommentsFromCommentPush = true
}
