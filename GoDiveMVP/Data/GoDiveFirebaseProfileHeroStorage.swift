import Foundation
import os
import FirebaseAuth
import FirebaseStorage

/// Friend-visible profile hero (tagged media mirror) — `users/{uid}/profileHero.jpg` or `.mp4`.
enum GoDiveFirebaseProfileHeroStorage: Sendable {
    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "FirebaseProfileHero"
    )

    nonisolated static let imageObjectName = "profileHero.jpg"
    nonisolated static let videoObjectName = "profileHero.mp4"

    nonisolated static func objectPath(uid: String, kind: GoDiveProfileHeroMediaKind) -> String {
        let name = kind == .video ? videoObjectName : imageObjectName
        return "users/\(uid)/\(name)"
    }

    @MainActor
    static func uploadHero(
        _ data: Data,
        kind: GoDiveProfileHeroMediaKind
    ) async throws -> String {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else {
            throw UploadError.notConfigured
        }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            throw UploadError.notSignedIn
        }
        guard !data.isEmpty else { throw UploadError.emptyData }

        if kind == .image {
            try await deleteObjectIfPresent(uid: uid, kind: .video)
        } else {
            try await deleteObjectIfPresent(uid: uid, kind: .image)
        }

        let ref = Storage.storage().reference().child(objectPath(uid: uid, kind: kind))
        let metadata = StorageMetadata()
        metadata.contentType = kind == .video ? "video/mp4" : "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        log.notice("Profile hero uploaded (kind=\(kind.rawValue, privacy: .public))")
        return url.absoluteString
    }

    @MainActor
    static func deleteAllHeroMediaIfPresent() async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        try? await deleteObjectIfPresent(uid: uid, kind: .image)
        try? await deleteObjectIfPresent(uid: uid, kind: .video)
    }

    @MainActor
    private static func deleteObjectIfPresent(uid: String, kind: GoDiveProfileHeroMediaKind) async throws {
        let ref = Storage.storage().reference().child(objectPath(uid: uid, kind: kind))
        do {
            try await ref.delete()
        } catch {
            log.notice("Profile hero delete skipped: \(String(describing: error), privacy: .private)")
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
            case .emptyData: "Profile hero data is empty."
            }
        }
    }
}
