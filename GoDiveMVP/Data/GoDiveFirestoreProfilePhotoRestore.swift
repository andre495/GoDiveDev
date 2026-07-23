import FirebaseAuth
import FirebaseFirestore
import Foundation
import os
import SwiftData

/// Hydrates **`UserProfile.profilePhoto`** from Firestore **`photoURL`** / Storage after reinstall when
/// CloudKit has not yet returned local JPEG bytes (Firebase social profile may still have the avatar).
enum GoDiveFirestoreProfilePhotoRestore: Sendable {
    nonisolated static let maxDownloadBytes = 5 * 1024 * 1024

    private nonisolated static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "FirestoreProfilePhotoRestore"
    )

    nonisolated static func needsLocalRestore(_ profile: UserProfile) -> Bool {
        guard let data = profile.profilePhoto else { return true }
        return data.isEmpty
    }

    /// Downloads a previously uploaded avatar when the local profile row has no photo data.
    @MainActor
    @discardableResult
    static func restoreIntoLocalProfileIfNeeded(
        profile: UserProfile,
        modelContext: ModelContext
    ) async -> Bool {
        guard needsLocalRestore(profile) else { return false }

        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return false }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return false }

        guard let remoteURLString = await fetchRemotePhotoURL(uid: uid) else { return false }
        guard let downloadURL = GoDiveRemoteURLPolicy.sanitizedFirebaseStorageURL(from: remoteURLString) else {
            return false
        }

        do {
            let jpeg = try await downloadCappedJPEG(from: downloadURL)
            guard !jpeg.isEmpty else { return false }
            let profileID = profile.id
            guard let live = try? UserProfileStore.profile(id: profileID, modelContext: modelContext) else {
                return false
            }
            live.profilePhoto = jpeg
            try modelContext.save()
            log.notice("Restored profile photo from Firebase social profile")
            return true
        } catch {
            log.error("Profile photo restore failed: \(String(describing: error), privacy: .private)")
            return false
        }
    }

    @MainActor
    private static func fetchRemotePhotoURL(uid: String) async -> String? {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .getDocument()
            let fromDoc = (snapshot.data()?["photoURL"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let fromDoc, !fromDoc.isEmpty {
                return fromDoc
            }
        } catch {
            log.error("Firestore photoURL read failed: \(String(describing: error), privacy: .private)")
        }
        return nil
    }

    private nonisolated static func downloadCappedJPEG(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw RestoreError.badHTTP
        }

        var data = Data()
        data.reserveCapacity(min(maxDownloadBytes, 256_000))
        for try await byte in bytes {
            data.append(byte)
            if data.count > maxDownloadBytes {
                throw RestoreError.tooLarge
            }
        }
        return data
    }

    enum RestoreError: Error, Equatable {
        case badHTTP
        case tooLarge
    }
}
