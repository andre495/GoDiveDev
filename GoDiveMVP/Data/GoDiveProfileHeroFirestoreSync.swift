import Foundation
import os
import FirebaseAuth
import FirebaseFirestore

/// Uploads the owner's profile hero tagged media to Storage + merges Firestore hero fields for friends.
@MainActor
enum GoDiveProfileHeroFirestoreSync {
    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "ProfileHeroFirestore"
    )

    private static var lastSyncedMediaID: UUID?
    private static var syncTask: Task<Void, Never>?
    private static var pendingForceUpload = false

    static func scheduleSyncIfNeeded(heroMedia: DiveMediaPhoto?, force: Bool = false) {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard Auth.auth().currentUser != nil else { return }

        if force {
            pendingForceUpload = true
        }

        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            let shouldForce = pendingForceUpload
            pendingForceUpload = false
            await syncNow(heroMedia: heroMedia, force: shouldForce)
        }
    }

    static func syncNow(heroMedia: DiveMediaPhoto?, force: Bool = false) async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }

        if let heroMedia {
            if !force, lastSyncedMediaID == heroMedia.id { return }
            guard let payload = await GoDiveProfileHeroMediaExport.exportPayload(for: heroMedia) else {
                return
            }
            do {
                let url: String
                let kind: GoDiveProfileHeroMediaKind
                switch payload {
                case .image(let data):
                    url = try await GoDiveFirebaseProfileHeroStorage.uploadHero(data, kind: .image)
                    kind = .image
                case .video(let data):
                    url = try await GoDiveFirebaseProfileHeroStorage.uploadHero(data, kind: .video)
                    kind = .video
                }
                try await mergeHeroFields(uid: uid, url: url, kind: kind, sourceMediaID: heroMedia.id)
                lastSyncedMediaID = heroMedia.id
            } catch {
                log.error("Profile hero sync failed: \(String(describing: error), privacy: .private)")
            }
        } else {
            guard lastSyncedMediaID != nil else { return }
            await GoDiveFirebaseProfileHeroStorage.deleteAllHeroMediaIfPresent()
            try? await mergeHeroFields(uid: uid, url: nil, kind: nil, sourceMediaID: nil)
            lastSyncedMediaID = nil
        }
    }

    private static func mergeHeroFields(
        uid: String,
        url: String?,
        kind: GoDiveProfileHeroMediaKind?,
        sourceMediaID: UUID?
    ) async throws {
        let ref = Firestore.firestore().collection("users").document(uid)
        var fields: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp(),
            "schemaVersion": GoDiveFirestoreUserProfileMapping.schemaVersion,
        ]
        if let url, let kind, !url.isEmpty {
            fields["profileHeroURL"] = url
            fields["profileHeroMediaKind"] = kind.rawValue
            if let sourceMediaID {
                fields["profileHeroSourceMediaID"] = sourceMediaID.uuidString
            }
        } else {
            fields["profileHeroURL"] = FieldValue.delete()
            fields["profileHeroMediaKind"] = FieldValue.delete()
            fields["profileHeroSourceMediaID"] = FieldValue.delete()
        }
        try await ref.setData(fields, merge: true)
    }

    /// Test hook — reset debounce state between tests.
    static func resetSessionSyncStateForTesting() {
        lastSyncedMediaID = nil
        pendingForceUpload = false
        syncTask?.cancel()
        syncTask = nil
    }
}
