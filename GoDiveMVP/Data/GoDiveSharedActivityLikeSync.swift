import Foundation
import os
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Friend likes on **`users/{ownerUid}/sharedDives/{activityId}/likes/{likerUid}`**.
/// Tally (`likeCount` on the parent projection) and owner push are Cloud Function–owned.
enum GoDiveSharedActivityLikeSync: Sendable {
    nonisolated static let likesSubcollection = "likes"
    nonisolated static let likeCountField = "likeCount"
    nonisolated static let displayNameField = "displayName"
    nonisolated static let createdAtField = "createdAt"
    nonisolated static let maxDisplayNameLength = 80

    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "SharedActivityLike"
    )

    /// Firestore-safe display name for a like doc (non-empty, capped).
    nonisolated static func sanitizedLikeDisplayName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "A dive buddy" : trimmed
        if base.count <= maxDisplayNameLength { return base }
        let end = base.index(base.startIndex, offsetBy: maxDisplayNameLength)
        return String(base[..<end])
    }

    nonisolated static func likeDocumentPath(
        ownerUID: String,
        activityID: String,
        likerUID: String
    ) -> String {
        "users/\(ownerUID)/\(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)/\(activityID)/\(likesSubcollection)/\(likerUID)"
    }

    /// Creates or deletes the current user's like doc for a friend's shared activity.
    @MainActor
    @discardableResult
    static func setLiked(
        ownerUID: String,
        activityID: String,
        liked: Bool,
        likerDisplayName: String
    ) async -> Bool {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return false }
        guard let rawUID = Auth.auth().currentUser?.uid else { return false }
        let likerUID = rawUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !likerUID.isEmpty else { return false }

        let owner = ownerUID.trimmingCharacters(in: .whitespacesAndNewlines)
        let activity = activityID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !owner.isEmpty, !activity.isEmpty, owner != likerUID else { return false }

        let ref = Firestore.firestore()
            .collection("users")
            .document(owner)
            .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
            .document(activity)
            .collection(likesSubcollection)
            .document(likerUID)

        do {
            if liked {
                try await ref.setData([
                    displayNameField: sanitizedLikeDisplayName(likerDisplayName),
                    createdAtField: FieldValue.serverTimestamp(),
                ])
            } else {
                try await ref.delete()
            }
            return true
        } catch {
            log.error("Shared activity like write failed: \(String(describing: error), privacy: .private)")
            return false
        }
        #else
        return false
        #endif
    }

    /// Whether the signed-in user has liked a single shared activity.
    @MainActor
    static func isLikedByCurrentUser(ownerUID: String, activityID: String) async -> Bool {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return false }
        guard let rawUID = Auth.auth().currentUser?.uid else { return false }
        let likerUID = rawUID.trimmingCharacters(in: .whitespacesAndNewlines)
        let owner = ownerUID.trimmingCharacters(in: .whitespacesAndNewlines)
        let activity = activityID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !likerUID.isEmpty, !owner.isEmpty, !activity.isEmpty else { return false }

        let ref = Firestore.firestore()
            .collection("users")
            .document(owner)
            .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
            .document(activity)
            .collection(likesSubcollection)
            .document(likerUID)
        do {
            return try await ref.getDocument().exists
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    /// Row IDs (`friendUID_activityID`) the current user has liked among the given feed rows.
    @MainActor
    static func likedRowIDsForCurrentUser(
        among rows: [LogbookBuddyFeedPresentation.Row]
    ) async -> Set<String> {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return [] }
        guard let rawUID = Auth.auth().currentUser?.uid else { return [] }
        let likerUID = rawUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !likerUID.isEmpty, !rows.isEmpty else { return [] }

        var liked = Set<String>()
        await withTaskGroup(of: String?.self) { group in
            for row in rows {
                let ownerUID = row.friendUID
                let activityID = row.dive.id
                let rowID = row.id
                group.addTask {
                    let ref = Firestore.firestore()
                        .collection("users")
                        .document(ownerUID)
                        .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
                        .document(activityID)
                        .collection(likesSubcollection)
                        .document(likerUID)
                    do {
                        let snap = try await ref.getDocument()
                        return snap.exists ? rowID : nil
                    } catch {
                        return nil
                    }
                }
            }
            for await rowID in group {
                if let rowID {
                    liked.insert(rowID)
                }
            }
        }
        return liked
        #else
        return []
        #endif
    }

    #if canImport(FirebaseFirestore)
    /// Deletes all like docs under a shared activity (owner wipe / unshare).
    @MainActor
    static func deleteAllLikes(for activityRef: DocumentReference) async {
        do {
            let likes = try await activityRef.collection(likesSubcollection).getDocuments()
            for doc in likes.documents {
                try await doc.reference.delete()
            }
        } catch {
            log.error("Shared activity likes wipe failed: \(String(describing: error), privacy: .private)")
        }
    }
    #endif

    /// Parses `users/{owner}/sharedDives/{activity}/likes/{liker}` → Buddy Feed row id.
    nonisolated static func rowID(fromLikeDocumentPath path: String) -> String? {
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count >= 6,
              parts[0] == "users",
              parts[2] == GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection,
              parts[4] == likesSubcollection
        else { return nil }
        let ownerUID = parts[1]
        let activityID = parts[3]
        guard !ownerUID.isEmpty, !activityID.isEmpty else { return nil }
        return LogbookBuddyFeedPresentation.rowID(friendUID: ownerUID, diveDocumentID: activityID)
    }
}
