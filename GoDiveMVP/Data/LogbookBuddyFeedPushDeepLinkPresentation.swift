import Foundation

/// Push-notification deep link → Logbook **Buddy Feed** → shared activity detail.
///
/// Payload already carries the target activity ID (the single shared activity, or the most
/// recent in a batch). This helper waits until feed (or a direct projection fetch) has that
/// row before navigation so Back returns to a feed that includes the activity.
enum LogbookBuddyFeedPushDeepLinkPresentation: Sendable {
    nonisolated static let maxLoadAttempts = 5
    nonisolated static let retryDelayNanoseconds: UInt64 = 400_000_000

    nonisolated enum FeedResolve: Equatable, Sendable {
        /// Target already present in the loaded Buddy Feed rows.
        case readyInFeed
        /// Feed loaded but target missing — try a direct `sharedDives` document fetch.
        case fetchDirectProjection
    }

    nonisolated static func resolveAfterFeedLoad(
        rows: [LogbookBuddyFeedPresentation.Row],
        friendUID: String,
        diveDocumentID: String
    ) -> FeedResolve {
        if LogbookBuddyFeedPresentation.containsRow(
            in: rows,
            friendUID: friendUID,
            diveDocumentID: diveDocumentID
        ) {
            return .readyInFeed
        }
        return .fetchDirectProjection
    }

    nonisolated static func shouldRetryAfterMiss(attemptIndex: Int, maxAttempts: Int = maxLoadAttempts) -> Bool {
        attemptIndex + 1 < maxAttempts
    }

    /// Builds a feed row from a directly fetched projection (when the list snapshot lagged).
    nonisolated static func row(
        friendUID: String,
        friendDisplayName: String,
        friendPhotoURL: String?,
        dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> LogbookBuddyFeedPresentation.Row {
        LogbookBuddyFeedPresentation.Row(
            id: LogbookBuddyFeedPresentation.rowID(
                friendUID: friendUID,
                diveDocumentID: dive.id
            ),
            friendUID: friendUID,
            friendDisplayName: friendDisplayName,
            friendPhotoURL: friendPhotoURL,
            dive: dive
        )
    }
}
