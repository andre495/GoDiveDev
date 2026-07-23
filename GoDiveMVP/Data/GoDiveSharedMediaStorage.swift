import Foundation
import os
import FirebaseAuth
import FirebaseStorage

/// Opt-in dive media preview uploads for friend-visible shares.
enum GoDiveSharedMediaStorage: Sendable {
    private static let log = Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "FriendShareMedia")

    nonisolated static func objectPath(ownerUID: String, diveID: UUID, photoID: UUID) -> String {
        "users/\(ownerUID)/sharedMedia/\(diveID.uuidString)/\(photoID.uuidString).jpg"
    }

    nonisolated static func ownerPrefix(ownerUID: String) -> String {
        "users/\(ownerUID)/sharedMedia/"
    }

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

        let ref = Storage.storage().reference().child(objectPath(ownerUID: ownerUID, diveID: diveID, photoID: photoID))
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
    static func deleteAllPreviews(ownerUID: String, diveID: UUID) async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        let prefix = "users/\(ownerUID)/sharedMedia/\(diveID.uuidString)/"
        let ref = Storage.storage().reference().child(prefix)
        do {
            let list = try await ref.listAll()
            for item in list.items {
                try await item.delete()
            }
        } catch {
            log.notice("Shared media dive wipe skipped: \(String(describing: error), privacy: .private)")
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
            }
        } catch {
            log.notice("Shared media owner wipe skipped: \(String(describing: error), privacy: .private)")
        }
    }
}
