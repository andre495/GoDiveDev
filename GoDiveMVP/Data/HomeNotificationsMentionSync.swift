import Foundation
import os
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Mentions of the signed-in user in comments on **friend** shared activities (Buddy Feed).
enum HomeNotificationsMentionSync: Sendable {
    nonisolated static let maxFeedActivitiesToScan = 40

    struct Event: Equatable, Sendable, Identifiable, Hashable {
        var id: String
        var activityID: String
        var activityKind: FriendSharedActivityKind
        var ownerUID: String
        var actorUID: String
        var actorDisplayName: String
        var createdAt: Date
        var siteName: String?
        var commentText: String?
        /// Feed row for navigation when available.
        var feedRow: LogbookBuddyFeedPresentation.Row?
    }

    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "HomeNotificationsMention"
    )

    /// Scans friend-shared activities with comments for `@mentions` of the current user.
    @MainActor
    static func fetchEvents(
        feedRows: [LogbookBuddyFeedPresentation.Row],
        maxActivities: Int = maxFeedActivitiesToScan
    ) async -> [Event] {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return [] }
        guard let rawUID = Auth.auth().currentUser?.uid else { return [] }
        let me = rawUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !me.isEmpty else { return [] }

        let candidates = feedRows
            .filter { $0.dive.commentCount > 0 && $0.friendUID != me }
            .prefix(max(1, maxActivities))

        var events: [Event] = []
        await withTaskGroup(of: [Event].self) { group in
            for row in candidates {
                group.addTask {
                    await fetchMentionEvents(for: row, currentUID: me)
                }
            }
            for await batch in group {
                events.append(contentsOf: batch)
            }
        }
        return events
        #else
        return []
        #endif
    }

    #if canImport(FirebaseFirestore)
    @MainActor
    private static func fetchMentionEvents(
        for row: LogbookBuddyFeedPresentation.Row,
        currentUID: String
    ) async -> [Event] {
        let comments = await GoDiveSharedActivityCommentSync.fetchComments(
            ownerUID: row.friendUID,
            activityID: row.dive.id
        )
        return comments.compactMap { comment in
            let authorUID = comment.authorUID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !authorUID.isEmpty, authorUID != currentUID else { return nil }
            guard comment.mentionedUIDs.contains(currentUID) else { return nil }
            return Event(
                id: "mention-\(row.friendUID)-\(row.dive.id)-\(comment.id)",
                activityID: row.dive.id,
                activityKind: row.dive.resolvedActivityKind,
                ownerUID: row.friendUID,
                actorUID: authorUID,
                actorDisplayName: comment.displayName,
                createdAt: comment.createdAt ?? .distantPast,
                siteName: trimmedNonEmpty(row.dive.siteName),
                commentText: comment.text,
                feedRow: row
            )
        }
    }

    nonisolated private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
    #endif
}
