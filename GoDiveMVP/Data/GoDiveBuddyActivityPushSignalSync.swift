import Foundation
import os
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// One-shot Firestore signal so `notifyBuddyActivityShared` runs after a full projection
/// upsert — avoids missed pushes when `sharedDives` only receives merge updates.
///
/// Already-shared activities are recognized by an existing **`sharedDives`** doc and/or local
/// **`friendSharePushSignalRecorded`** (hydrated from Firebase on republish when local state was
/// lost after rebuild). Signal docs themselves are deleted after FCM, so they are not durable.
enum GoDiveBuddyActivityPushSignalSync: Sendable {
    nonisolated static let signalsSubcollection = "buddySharePushSignals"

    /// Whether the upsert path should write a push signal for this activity.
    /// Never signals when the projection already exists in Firebase (already viewable by buddies).
    nonisolated static func shouldRecordPushSignal(
        projectionAlreadyExisted: Bool,
        pushSignalAlreadyRecorded: Bool
    ) -> Bool {
        !projectionAlreadyExisted && !pushSignalAlreadyRecorded
    }

    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "BuddyActivityPushSignal"
    )

    /// Creates `users/{uid}/buddySharePushSignals/{activityId}` once per activity share.
    /// - Returns: `true` when a new signal doc was written (or already existed — still counts as recorded).
    @MainActor
    @discardableResult
    static func recordFirstShareIfNeeded(
        ownerUID: String,
        activityID: UUID,
        activityKind: FriendSharedActivityKind,
        startTime: Date,
        taggedBuddies: [[String: Any]]
    ) async -> Bool {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return false }
        guard Auth.auth().currentUser?.uid == ownerUID else { return false }

        let ref = Firestore.firestore()
            .collection("users")
            .document(ownerUID)
            .collection(signalsSubcollection)
            .document(activityID.uuidString)

        let fields: [String: Any] = [
            "activityKind": activityKind.rawValue,
            "startTime": Timestamp(date: startTime),
            "taggedBuddies": taggedBuddies,
            "createdAt": FieldValue.serverTimestamp(),
        ]

        do {
            // Transactional create-once: owner must be allowed to read the doc (rules).
            let wrote = try await Firestore.firestore().runTransaction { transaction, errorPointer -> Any? in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(ref)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                if snapshot.exists {
                    return false
                }
                transaction.setData(fields, forDocument: ref)
                return true
            }
            // Whether we created it or it already existed, the activity has been signaled.
            if wrote as? Bool == true {
                log.notice("Buddy activity push signal recorded")
            }
            return true
        } catch {
            log.error("Buddy activity push signal create failed: \(String(describing: error), privacy: .private)")
            return false
        }
        #else
        return false
        #endif
    }

    @MainActor
    static func deleteSignal(ownerUID: String, activityID: UUID) async {
        #if canImport(FirebaseFirestore)
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }

        let ref = Firestore.firestore()
            .collection("users")
            .document(ownerUID)
            .collection(signalsSubcollection)
            .document(activityID.uuidString)
        try? await ref.delete()
        #endif
    }
}
