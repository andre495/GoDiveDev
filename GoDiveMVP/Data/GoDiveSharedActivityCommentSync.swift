import Foundation
import os
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Friend comments on **`users/{ownerUid}/sharedDives/{activityId}/comments/{commentId}`**.
/// Tally (`commentCount` on the parent projection) and owner push are Cloud Function–owned.
enum GoDiveSharedActivityCommentSync: Sendable {
    nonisolated static let commentsSubcollection = "comments"
    nonisolated static let commentCountField = "commentCount"
    nonisolated static let authorUIDField = "authorUid"
    nonisolated static let displayNameField = "displayName"
    nonisolated static let textField = "text"
    nonisolated static let mentionedUIDsField = "mentionedUids"
    nonisolated static let createdAtField = "createdAt"
    nonisolated static let maxDisplayNameLength = 80
    nonisolated static let maxCommentTextLength = 500
    nonisolated static let maxMentionedUIDs = GoDiveMentionPresentation.maxMentionedUIDs

    struct Comment: Equatable, Identifiable, Sendable {
        var id: String
        var authorUID: String
        var displayName: String
        var text: String
        var createdAt: Date?
        var mentionedUIDs: [String] = []
    }

    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "SharedActivityComment"
    )

    /// Firestore-safe display name for a comment doc (non-empty, capped).
    nonisolated static func sanitizedCommentDisplayName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "A dive buddy" : trimmed
        if base.count <= maxDisplayNameLength { return base }
        let end = base.index(base.startIndex, offsetBy: maxDisplayNameLength)
        return String(base[..<end])
    }

    /// Sanitized comment body; `nil` when empty after trim.
    nonisolated static func sanitizedCommentText(_ raw: String) -> String? {
        GoDiveInputSanitization.sanitizedOptionalText(raw, maxLength: maxCommentTextLength)
    }

    nonisolated static func commentsCollectionPath(ownerUID: String, activityID: String) -> String {
        "users/\(ownerUID)/\(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)/\(activityID)/\(commentsSubcollection)"
    }

    /// Fetches comments oldest-first for display under the activity.
    @MainActor
    static func fetchComments(ownerUID: String, activityID: String) async -> [Comment] {
        #if canImport(FirebaseFirestore)
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return [] }

        let owner = ownerUID.trimmingCharacters(in: .whitespacesAndNewlines)
        let activity = activityID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !owner.isEmpty, !activity.isEmpty else { return [] }

        let ref = Firestore.firestore()
            .collection("users")
            .document(owner)
            .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
            .document(activity)
            .collection(commentsSubcollection)
            .order(by: createdAtField, descending: false)

        do {
            let snap = try await ref.getDocuments()
            return snap.documents.compactMap { doc in
                parseComment(id: doc.documentID, data: doc.data())
            }
        } catch {
            log.error("Shared activity comments fetch failed: \(String(describing: error), privacy: .private)")
            return []
        }
        #else
        return []
        #endif
    }

    /// Posts a comment as the signed-in user. Returns the new comment when the write succeeds.
    /// `mentionedUIDs` should already be resolved from `@` mentions against mutual friends.
    @MainActor
    static func postComment(
        ownerUID: String,
        activityID: String,
        text: String,
        displayName: String,
        mentionedUIDs: [String] = []
    ) async -> Comment? {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return nil }
        guard let rawUID = Auth.auth().currentUser?.uid else { return nil }
        let authorUID = rawUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !authorUID.isEmpty else { return nil }

        let owner = ownerUID.trimmingCharacters(in: .whitespacesAndNewlines)
        let activity = activityID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !owner.isEmpty, !activity.isEmpty else { return nil }
        guard let body = sanitizedCommentText(text) else { return nil }

        let name = sanitizedCommentDisplayName(displayName)
        let mentions = GoDiveMentionPresentation.sanitizedMentionedUIDs(
            mentionedUIDs,
            excludingUID: authorUID,
            maxCount: maxMentionedUIDs
        )
        let ref = Firestore.firestore()
            .collection("users")
            .document(owner)
            .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
            .document(activity)
            .collection(commentsSubcollection)
            .document()

        do {
            var payload: [String: Any] = [
                authorUIDField: authorUID,
                displayNameField: name,
                textField: body,
                createdAtField: FieldValue.serverTimestamp(),
            ]
            if !mentions.isEmpty {
                payload[mentionedUIDsField] = mentions
            }
            try await ref.setData(payload)
            return Comment(
                id: ref.documentID,
                authorUID: authorUID,
                displayName: name,
                text: body,
                createdAt: Date(),
                mentionedUIDs: mentions
            )
        } catch {
            log.error("Shared activity comment write failed: \(String(describing: error), privacy: .private)")
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Deletes a comment when the signed-in user is the author.
    @MainActor
    @discardableResult
    static func deleteComment(
        ownerUID: String,
        activityID: String,
        commentID: String
    ) async -> Bool {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return false }
        guard Auth.auth().currentUser?.uid != nil else { return false }

        let owner = ownerUID.trimmingCharacters(in: .whitespacesAndNewlines)
        let activity = activityID.trimmingCharacters(in: .whitespacesAndNewlines)
        let comment = commentID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !owner.isEmpty, !activity.isEmpty, !comment.isEmpty else { return false }

        let ref = Firestore.firestore()
            .collection("users")
            .document(owner)
            .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
            .document(activity)
            .collection(commentsSubcollection)
            .document(comment)

        do {
            try await ref.delete()
            return true
        } catch {
            log.error("Shared activity comment delete failed: \(String(describing: error), privacy: .private)")
            return false
        }
        #else
        return false
        #endif
    }

    #if canImport(FirebaseFirestore)
    /// Deletes all comment docs under a shared activity (owner wipe / unshare).
    @MainActor
    static func deleteAllComments(for activityRef: DocumentReference) async {
        do {
            let comments = try await activityRef.collection(commentsSubcollection).getDocuments()
            for doc in comments.documents {
                try await doc.reference.delete()
            }
        } catch {
            log.error("Shared activity comments wipe failed: \(String(describing: error), privacy: .private)")
        }
    }
    #endif

    #if canImport(FirebaseFirestore)
    nonisolated static func parseComment(id: String, data: [String: Any]) -> Comment? {
        guard let authorUID = (data[authorUIDField] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !authorUID.isEmpty
        else { return nil }
        guard let text = sanitizedCommentText(data[textField] as? String ?? "") else { return nil }
        let displayName = sanitizedCommentDisplayName(data[displayNameField] as? String ?? "")
        let createdAt: Date?
        if let timestamp = data[createdAtField] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else if let date = data[createdAtField] as? Date {
            createdAt = date
        } else {
            createdAt = nil
        }
        let mentioned = parseMentionedUIDs(data[mentionedUIDsField], excludingUID: authorUID)
        return Comment(
            id: id,
            authorUID: authorUID,
            displayName: displayName,
            text: text,
            createdAt: createdAt,
            mentionedUIDs: mentioned
        )
    }
    #else
    nonisolated static func parseComment(id: String, data: [String: Any]) -> Comment? {
        guard let authorUID = (data[authorUIDField] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !authorUID.isEmpty
        else { return nil }
        guard let text = sanitizedCommentText(data[textField] as? String ?? "") else { return nil }
        let displayName = sanitizedCommentDisplayName(data[displayNameField] as? String ?? "")
        let createdAt = data[createdAtField] as? Date
        let mentioned = parseMentionedUIDs(data[mentionedUIDsField], excludingUID: authorUID)
        return Comment(
            id: id,
            authorUID: authorUID,
            displayName: displayName,
            text: text,
            createdAt: createdAt,
            mentionedUIDs: mentioned
        )
    }
    #endif

    nonisolated static func parseMentionedUIDs(
        _ raw: Any?,
        excludingUID: String?
    ) -> [String] {
        let list = (raw as? [String]) ?? (raw as? [Any])?.compactMap { $0 as? String } ?? []
        return GoDiveMentionPresentation.sanitizedMentionedUIDs(
            list,
            excludingUID: excludingUID,
            maxCount: maxMentionedUIDs
        )
    }
}
