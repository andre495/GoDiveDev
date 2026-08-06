import Foundation
import os
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Likes / comments on the signed-in user's own **`sharedDives`** for Home Notifications.
enum HomeNotificationsOwnedSocialSync: Sendable {
    /// Cap how many owned shared activities we scan for social events.
    nonisolated static let maxOwnedActivitiesToScan = 40

    struct Event: Equatable, Sendable, Identifiable, Hashable {
        enum Kind: Equatable, Sendable, Hashable {
            case like
            case comment
            /// Current user was `@mentioned` in a comment (prefer over `.comment` for owners).
            case mention
        }

        var id: String
        var kind: Kind
        var activityID: UUID
        var activityKind: FriendSharedActivityKind
        var actorUID: String
        var actorDisplayName: String
        var createdAt: Date
        var siteName: String?
        var commentText: String?
    }

    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "HomeNotificationsOwnedSocial"
    )

    /// Fetches like + comment events on the current user's shared activities (excludes self).
    @MainActor
    static func fetchEvents(
        maxActivities: Int = maxOwnedActivitiesToScan
    ) async -> [Event] {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return [] }
        guard let rawUID = Auth.auth().currentUser?.uid else { return [] }
        let ownerUID = rawUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ownerUID.isEmpty else { return [] }

        let activities = await fetchOwnedSharedActivitySummaries(
            ownerUID: ownerUID,
            limit: max(1, maxActivities)
        )
        guard !activities.isEmpty else { return [] }

        var events: [Event] = []
        await withTaskGroup(of: [Event].self) { group in
            for summary in activities {
                group.addTask {
                    await fetchEvents(for: summary, ownerUID: ownerUID)
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
    private struct OwnedSharedActivitySummary: Sendable {
        var activityID: UUID
        var activityKind: FriendSharedActivityKind
        var siteName: String?
        var likeCount: Int
        var commentCount: Int
    }

    @MainActor
    private static func fetchOwnedSharedActivitySummaries(
        ownerUID: String,
        limit: Int
    ) async -> [OwnedSharedActivitySummary] {
        do {
            let snap = try await Firestore.firestore()
                .collection("users")
                .document(ownerUID)
                .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
                .getDocuments()
            let summaries = snap.documents.compactMap { doc -> OwnedSharedActivitySummary? in
                guard let activityID = UUID(uuidString: doc.documentID) else { return nil }
                let data = doc.data()
                let kind = FriendSharedActivityKind(rawValue: data["activityKind"] as? String ?? "")
                    ?? .scubaDive
                let likeCount = (data[GoDiveSharedActivityLikeSync.likeCountField] as? Int) ?? 0
                let commentCount = (data[GoDiveSharedActivityCommentSync.commentCountField] as? Int)
                    ?? 0
                let site = (data["siteName"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return OwnedSharedActivitySummary(
                    activityID: activityID,
                    activityKind: kind,
                    siteName: (site?.isEmpty == false) ? site : nil,
                    likeCount: max(0, likeCount),
                    commentCount: max(0, commentCount)
                )
            }
            // Prefer activities that already show social activity; then newest document id order.
            return Array(
                summaries
                    .sorted { lhs, rhs in
                        let lhsScore = (lhs.likeCount > 0 || lhs.commentCount > 0) ? 1 : 0
                        let rhsScore = (rhs.likeCount > 0 || rhs.commentCount > 0) ? 1 : 0
                        if lhsScore != rhsScore { return lhsScore > rhsScore }
                        return lhs.activityID.uuidString > rhs.activityID.uuidString
                    }
                    .prefix(limit)
            )
        } catch {
            log.error(
                "Owned sharedDives fetch for notifications failed: \(String(describing: error), privacy: .private)"
            )
            return []
        }
    }

    @MainActor
    private static func fetchEvents(
        for summary: OwnedSharedActivitySummary,
        ownerUID: String
    ) async -> [Event] {
        var events: [Event] = []
        if summary.likeCount > 0 {
            events.append(contentsOf: await fetchLikeEvents(for: summary, ownerUID: ownerUID))
        }
        if summary.commentCount > 0 {
            events.append(contentsOf: await fetchCommentEvents(for: summary, ownerUID: ownerUID))
        }
        return events
    }

    @MainActor
    private static func fetchLikeEvents(
        for summary: OwnedSharedActivitySummary,
        ownerUID: String
    ) async -> [Event] {
        let ref = Firestore.firestore()
            .collection("users")
            .document(ownerUID)
            .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
            .document(summary.activityID.uuidString)
            .collection(GoDiveSharedActivityLikeSync.likesSubcollection)
        do {
            let snap = try await ref.getDocuments()
            return snap.documents.compactMap { doc in
                let likerUID = doc.documentID.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !likerUID.isEmpty, likerUID != ownerUID else { return nil }
                let data = doc.data()
                let name = GoDiveSharedActivityLikeSync.sanitizedLikeDisplayName(
                    data[GoDiveSharedActivityLikeSync.displayNameField] as? String ?? ""
                )
                let createdAt = parseCreatedAt(
                    data[GoDiveSharedActivityLikeSync.createdAtField]
                ) ?? .distantPast
                return Event(
                    id: "like-\(summary.activityID.uuidString)-\(likerUID)",
                    kind: .like,
                    activityID: summary.activityID,
                    activityKind: summary.activityKind,
                    actorUID: likerUID,
                    actorDisplayName: name,
                    createdAt: createdAt,
                    siteName: summary.siteName,
                    commentText: nil
                )
            }
        } catch {
            log.error("Owned likes fetch for notifications failed: \(String(describing: error), privacy: .private)")
            return []
        }
    }

    @MainActor
    private static func fetchCommentEvents(
        for summary: OwnedSharedActivitySummary,
        ownerUID: String
    ) async -> [Event] {
        let comments = await GoDiveSharedActivityCommentSync.fetchComments(
            ownerUID: ownerUID,
            activityID: summary.activityID.uuidString
        )
        return comments.compactMap { comment in
            let authorUID = comment.authorUID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !authorUID.isEmpty, authorUID != ownerUID else { return nil }
            let mentionedMe = comment.mentionedUIDs.contains(ownerUID)
            return Event(
                id: mentionedMe
                    ? "mention-\(summary.activityID.uuidString)-\(comment.id)"
                    : "comment-\(summary.activityID.uuidString)-\(comment.id)",
                kind: mentionedMe ? .mention : .comment,
                activityID: summary.activityID,
                activityKind: summary.activityKind,
                actorUID: authorUID,
                actorDisplayName: comment.displayName,
                createdAt: comment.createdAt ?? .distantPast,
                siteName: summary.siteName,
                commentText: comment.text
            )
        }
    }

    nonisolated private static func parseCreatedAt(_ raw: Any?) -> Date? {
        if let timestamp = raw as? Timestamp {
            return timestamp.dateValue()
        }
        if let date = raw as? Date {
            return date
        }
        return nil
    }
    #endif
}
