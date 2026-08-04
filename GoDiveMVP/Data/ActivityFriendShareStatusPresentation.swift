import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Resolves buddy-share publish status for a single activity (Firestore + local queue) into the
/// settings footer model: an **upload in progress** banner while anything is still publishing,
/// then a checklist of what landed (activity / media / notes).
enum ActivityFriendShareStatusPresentation: Sendable {

    nonisolated enum ShareItemState: Sendable, Equatable {
        case off
        case inProgress
        case shared
    }

    /// One row per shareable component of the activity.
    nonisolated struct ShareStatusChecklist: Equatable, Sendable {
        var activity: ShareItemState
        var media: ShareItemState
        var notes: ShareItemState

        nonisolated var isUploading: Bool {
            activity == .inProgress || media == .inProgress || notes == .inProgress
        }
    }

    nonisolated struct FirestoreSnapshot: Equatable, Sendable {
        var documentExists: Bool
        var hasIncompleteMediaRows: Bool
        var mediaItemCount: Int
        var hasNotesField: Bool
    }

    /// Whether the notes component will actually publish (mode on **and** non-empty text —
    /// mirrors the projection mapping, which omits the `notes` field for empty text).
    nonisolated static func notesExpected(
        mode: ActivityFriendShareNotesMode,
        privateNotes: String?,
        publicNotes: String?
    ) -> Bool {
        let text: String?
        switch mode {
        case .off:
            return false
        case .privateNotes:
            text = privateNotes
        case .publicNotes:
            text = publicNotes
        }
        return !(text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Pure mapper from resolved inputs to the checklist. `nil` = sharing off for this activity.
    nonisolated static func shareStatusChecklist(
        shouldPublish: Bool,
        shareMediaEnabled: Bool,
        hasShareableMedia: Bool,
        notesExpected: Bool,
        hasPendingUpload: Bool,
        hasLocalPendingUpload: Bool = false,
        firestore: FirestoreSnapshot?
    ) -> ShareStatusChecklist? {
        guard shouldPublish else { return nil }

        let documentExists = firestore?.documentExists == true
        let activity: ShareItemState = documentExists ? .shared : .inProgress

        let media: ShareItemState
        if !shareMediaEnabled || !hasShareableMedia {
            media = .off
        } else if hasPendingUpload || hasLocalPendingUpload {
            media = .inProgress
        } else if let firestore,
                  firestore.documentExists,
                  firestore.mediaItemCount > 0,
                  !firestore.hasIncompleteMediaRows {
            media = .shared
        } else if let firestore, firestore.documentExists, firestore.mediaItemCount == 0 {
            // Activity doc landed but no media rows — not an active upload (failed or skipped).
            media = .off
        } else {
            media = .inProgress
        }

        let notes: ShareItemState
        if !notesExpected {
            notes = .off
        } else if documentExists, firestore?.hasNotesField == true {
            notes = .shared
        } else {
            notes = .inProgress
        }

        return ShareStatusChecklist(activity: activity, media: media, notes: notes)
    }

    @MainActor
    static func refreshChecklist(
        activityID: UUID,
        shouldPublish: Bool,
        shareMediaEnabled: Bool,
        hasShareableMedia: Bool,
        notesExpected: Bool,
        ownerUID: String?
    ) async -> ShareStatusChecklist? {
        guard shouldPublish else { return nil }

        let queuePending = await GoDiveSharedMediaUploadQueue.shared.hasPendingUpload(for: activityID)
        let localPending = hasLocalPendingContentUpload(
            ownerUID: ownerUID,
            activityID: activityID,
            shareMediaEnabled: shareMediaEnabled
        )

        var firestore: FirestoreSnapshot?
        if let ownerUID, !ownerUID.isEmpty {
            firestore = await fetchFirestoreSnapshot(ownerUID: ownerUID, activityID: activityID)
        }

        return shareStatusChecklist(
            shouldPublish: true,
            shareMediaEnabled: shareMediaEnabled,
            hasShareableMedia: hasShareableMedia,
            notesExpected: notesExpected,
            hasPendingUpload: queuePending,
            hasLocalPendingUpload: localPending,
            firestore: firestore
        )
    }

    @MainActor
    static func fetchFirestoreSnapshot(
        ownerUID: String,
        activityID: UUID
    ) async -> FirestoreSnapshot? {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return nil }
        guard Auth.auth().currentUser?.uid == ownerUID else { return nil }

        let reference = Firestore.firestore()
            .collection("users")
            .document(ownerUID)
            .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
            .document(activityID.uuidString)

        do {
            let snapshot = try await reference.getDocument()
            guard snapshot.exists else {
                return FirestoreSnapshot(
                    documentExists: false,
                    hasIncompleteMediaRows: false,
                    mediaItemCount: 0,
                    hasNotesField: false
                )
            }
            let data = snapshot.data()
            let mediaItems = data?["mediaItems"] as? [[String: Any]] ?? []
            let hasIncompleteMediaRows = mediaItems.contains { row in
                let thumbnail = (row["thumbnailURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !thumbnail.isEmpty else { return false }
                let content = (row["contentURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return content.isEmpty
            }
            let notes = (data?["notes"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return FirestoreSnapshot(
                documentExists: true,
                hasIncompleteMediaRows: hasIncompleteMediaRows,
                mediaItemCount: mediaItems.count,
                hasNotesField: !notes.isEmpty
            )
        } catch {
            return nil
        }
    }

    @MainActor
    private static func hasLocalPendingContentUpload(
        ownerUID: String?,
        activityID: UUID,
        shareMediaEnabled: Bool
    ) -> Bool {
        guard shareMediaEnabled, let ownerUID, !ownerUID.isEmpty else { return false }
        let activity = GoDiveSharedMediaPublishState.loadActivity(
            ownerUID: ownerUID,
            activityID: activityID
        )
        return activity.items.contains { record in
            !record.thumbnailURL.isEmpty && (record.contentURL ?? "").isEmpty
        }
    }
}
