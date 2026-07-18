import Foundation
import os
import FirebaseAuth
import FirebaseStorage

/// Uploads the signed-in user’s profile JPEG to Firebase Storage and returns a download URL for `photoURL`.
enum GoDiveFirebaseProfilePhotoStorage: Sendable {
    private static let log = Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "FirebaseProfilePhoto")

    /// Object path under the default bucket: `users/{uid}/profile.jpg`.
    nonisolated static func objectPath(uid: String) -> String {
        "users/\(uid)/profile.jpg"
    }

    @MainActor
    static func uploadProfileJPEG(_ data: Data) async throws -> String {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else {
            throw UploadError.notConfigured
        }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            throw UploadError.notSignedIn
        }
        guard !data.isEmpty else {
            throw UploadError.emptyData
        }

        let ref = Storage.storage().reference().child(objectPath(uid: uid))
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        log.notice("Profile photo uploaded uid=\(uid, privacy: .public)")
        return url.absoluteString
    }

    @MainActor
    static func deleteProfilePhotoIfPresent() async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let ref = Storage.storage().reference().child(objectPath(uid: uid))
        do {
            try await ref.delete()
            log.notice("Profile photo deleted uid=\(uid, privacy: .public)")
        } catch {
            log.notice("Profile photo delete skipped: \(String(describing: error), privacy: .public)")
        }
    }

    enum UploadError: Error, Equatable, LocalizedError {
        case notConfigured
        case notSignedIn
        case emptyData

        var errorDescription: String? {
            switch self {
            case .notConfigured: "Firebase is not configured."
            case .notSignedIn: "Not signed into Firebase."
            case .emptyData: "Profile photo data is empty."
            }
        }
    }
}
