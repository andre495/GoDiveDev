import Foundation
import os
import FirebaseAuth
import FirebaseStorage

/// Opt-in dive/snorkel media uploads for friend-visible shares (schema v3 tiered Storage).
enum GoDiveSharedMediaStorage: Sendable {
    nonisolated private static let log = Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "FriendShareMedia")

    /// Storage object file names under **`users/{uid}/sharedMedia/{activityId}/{mediaId}/`**.
    enum Tier: String, Sendable, CaseIterable {
        case thumb
        case photo
        case video

        nonisolated var fileName: String {
            switch self {
            case .thumb: return "thumb.jpg"
            case .photo: return "photo.jpg"
            case .video: return "video.mp4"
            }
        }

        nonisolated var contentType: String {
            switch self {
            case .thumb, .photo: return "image/jpeg"
            case .video: return "video/mp4"
            }
        }

        nonisolated var maxUploadBytes: Int {
            switch self {
            case .thumb: return GoDiveSharedMediaLimits.thumbMaxBytes
            case .photo: return GoDiveSharedMediaLimits.photoStorageMaxBytes
            case .video: return GoDiveSharedMediaLimits.videoStorageMaxBytes
            }
        }
    }

    /// Schema v3 nested object path.
    nonisolated static func objectPath(
        ownerUID: String,
        activityID: UUID,
        mediaID: UUID,
        tier: Tier
    ) -> String {
        "users/\(ownerUID)/sharedMedia/\(activityID.uuidString)/\(mediaID.uuidString)/\(tier.fileName)"
    }

    /// Legacy v2 flat preview path (`{mediaId}.jpg` beside activity folder).
    nonisolated static func legacyPreviewObjectPath(
        ownerUID: String,
        activityID: UUID,
        mediaID: UUID
    ) -> String {
        "users/\(ownerUID)/sharedMedia/\(activityID.uuidString)/\(mediaID.uuidString).jpg"
    }

    nonisolated static func activityMediaPrefix(ownerUID: String, activityID: UUID) -> String {
        "users/\(ownerUID)/sharedMedia/\(activityID.uuidString)/"
    }

    nonisolated static func ownerPrefix(ownerUID: String) -> String {
        "users/\(ownerUID)/sharedMedia/"
    }

    /// Firebase Storage upload — nonisolated so friend-share content/thumb phases stay off the main actor.
    nonisolated static func uploadTier(
        ownerUID: String,
        activityID: UUID,
        mediaID: UUID,
        tier: Tier,
        data: Data
    ) async -> String? {
        if tier == .video {
            return await uploadTierFile(
                ownerUID: ownerUID,
                activityID: activityID,
                mediaID: mediaID,
                tier: tier,
                fileData: data
            )
        }
        return await uploadTierData(
            ownerUID: ownerUID,
            activityID: activityID,
            mediaID: mediaID,
            tier: tier,
            data: data
        )
    }

    nonisolated private static func uploadTierData(
        ownerUID: String,
        activityID: UUID,
        mediaID: UUID,
        tier: Tier,
        data: Data
    ) async -> String? {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return nil }
        guard Auth.auth().currentUser?.uid == ownerUID else { return nil }
        guard !data.isEmpty, data.count <= tier.maxUploadBytes else { return nil }

        let path = objectPath(ownerUID: ownerUID, activityID: activityID, mediaID: mediaID, tier: tier)
        let ref = Storage.storage().reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = tier.contentType
        do {
            _ = try await ref.putDataAsync(data, metadata: metadata)
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch {
            log.error("Shared media tier upload failed: \(String(describing: error), privacy: .private)")
            return nil
        }
    }

    nonisolated private static func uploadTierFile(
        ownerUID: String,
        activityID: UUID,
        mediaID: UUID,
        tier: Tier,
        fileData: Data
    ) async -> String? {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return nil }
        guard Auth.auth().currentUser?.uid == ownerUID else { return nil }
        guard !fileData.isEmpty, fileData.count <= tier.maxUploadBytes else { return nil }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("godive-shared-\(mediaID.uuidString)-\(tier.fileName)")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        do {
            try fileData.write(to: tempURL, options: .atomic)
        } catch {
            return nil
        }

        let path = objectPath(ownerUID: ownerUID, activityID: activityID, mediaID: mediaID, tier: tier)
        let ref = Storage.storage().reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = tier.contentType
        do {
            _ = try await ref.putFileAsync(from: tempURL, metadata: metadata)
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch {
            log.error("Shared media file upload failed: \(String(describing: error), privacy: .private)")
            return nil
        }
    }

    /// Legacy v2 thumbnail upload — flat `{mediaId}.jpg` (removed once republish migrates objects).
    @MainActor
    static func uploadPreview(
        ownerUID: String,
        diveID: UUID,
        photoID: UUID,
        jpegData: Data
    ) async -> String? {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return nil }
        guard Auth.auth().currentUser?.uid == ownerUID else { return nil }
        guard !jpegData.isEmpty else { return nil }

        let ref = Storage.storage().reference().child(
            legacyPreviewObjectPath(ownerUID: ownerUID, activityID: diveID, mediaID: photoID)
        )
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        do {
            _ = try await ref.putDataAsync(jpegData, metadata: metadata)
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch {
            log.error("Shared media upload failed: \(String(describing: error), privacy: .private)")
            return nil
        }
    }

    @MainActor
    static func deleteMediaItem(ownerUID: String, activityID: UUID, mediaID: UUID) async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }

        let nestedPrefix = "users/\(ownerUID)/sharedMedia/\(activityID.uuidString)/\(mediaID.uuidString)/"
        let nestedRef = Storage.storage().reference().child(nestedPrefix)
        do {
            let list = try await nestedRef.listAll()
            for item in list.items {
                try await item.delete()
            }
        } catch {
            log.notice("Shared media item wipe skipped: \(String(describing: error), privacy: .private)")
        }

        let legacyRef = Storage.storage().reference().child(
            legacyPreviewObjectPath(ownerUID: ownerUID, activityID: activityID, mediaID: mediaID)
        )
        try? await legacyRef.delete()
    }

    @MainActor
    static func deleteAllPreviews(ownerUID: String, diveID: UUID) async {
        await deleteAllActivityMedia(ownerUID: ownerUID, activityID: diveID)
    }

    @MainActor
    static func deleteAllActivityMedia(ownerUID: String, activityID: UUID) async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        let ref = Storage.storage().reference().child(activityMediaPrefix(ownerUID: ownerUID, activityID: activityID))
        do {
            let list = try await ref.listAll()
            for item in list.items {
                try await item.delete()
            }
            for prefix in list.prefixes {
                let nested = try await prefix.listAll()
                for item in nested.items {
                    try await item.delete()
                }
            }
        } catch {
            log.notice("Shared media activity wipe skipped: \(String(describing: error), privacy: .private)")
        }
    }

    @MainActor
    static func deleteAllForOwner(ownerUID: String) async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        let ref = Storage.storage().reference().child(ownerPrefix(ownerUID: ownerUID))
        do {
            let list = try await ref.listAll()
            for item in list.items {
                try await item.delete()
            }
            for prefix in list.prefixes {
                let nested = try await prefix.listAll()
                for item in nested.items {
                    try await item.delete()
                }
                for nestedPrefix in nested.prefixes {
                    let deep = try await nestedPrefix.listAll()
                    for item in deep.items {
                        try await item.delete()
                    }
                }
            }
        } catch {
            log.notice("Shared media owner wipe skipped: \(String(describing: error), privacy: .private)")
        }
    }
}
