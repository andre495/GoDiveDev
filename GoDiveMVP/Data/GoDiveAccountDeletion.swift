import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import os

/// Permanently removes the signed-in diver’s local SwiftData (CloudKit-synced), Firestore social profile, Firebase Auth user, and Apple Sign in tokens.
enum GoDiveAccountDeletion: Sendable {

    private nonisolated static let log = Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "AccountDeletion")

    enum DeletionError: Error, Equatable, LocalizedError {
        case notSignedIn
        case missingAppleAuthorizationCode
        case missingFirebaseUser
        case firestoreFailed(String)
        case appleRevokeFailed(String)
        case firebaseDeleteFailed(String)
        case localDeleteFailed(String)

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "You need to be signed in to delete your account."
            case .missingAppleAuthorizationCode:
                return "Apple did not return an authorization code. Try again."
            case .missingFirebaseUser:
                return "Firebase session missing. Sign in again, then retry delete."
            case .firestoreFailed,
                 .appleRevokeFailed,
                 .firebaseDeleteFailed,
                 .localDeleteFailed:
                return GoDiveUserFacingError.accountDeletionFailed
            }
        }

        /// Coarse failure token for security logging (not shown in UI).
        nonisolated var securityEventDetail: String {
            switch self {
            case .notSignedIn: return "notSignedIn"
            case .missingAppleAuthorizationCode: return "missingAppleCode"
            case .missingFirebaseUser: return "missingFirebaseUser"
            case .firestoreFailed: return "firestore"
            case .appleRevokeFailed: return "appleRevoke"
            case .firebaseDeleteFailed: return "firebaseDelete"
            case .localDeleteFailed: return "localDelete"
            }
        }
    }

    /// Full account wipe after a fresh Sign in with Apple (for token revoke + Firebase reauth).
    @MainActor
    static func perform(
        profile: UserProfile,
        appleCredential: ASAuthorizationAppleIDCredential,
        rawNonce: String,
        modelContext: ModelContext
    ) async throws {
        let appleUserIdentifier = profile.appleUserIdentifier
        let profileID = profile.id

        guard let authCodeData = appleCredential.authorizationCode,
              let authCode = String(data: authCodeData, encoding: .utf8),
              !authCode.isEmpty
        else {
            let error = DeletionError.missingAppleAuthorizationCode
            recordDeletionFailure(error)
            throw error
        }

        GoDiveFirebaseBootstrap.configureIfNeeded()

        do {
            if GoDiveFirebaseBootstrap.isConfigured {
                try await reauthenticateFirebaseIfNeeded(
                    appleCredential: appleCredential,
                    rawNonce: rawNonce
                )
                try await deleteFirestoreSocialProfileIfNeeded()
                await GoDiveFirebaseProfilePhotoStorage.deleteProfilePhotoIfPresent()
                try await revokeAppleTokenAndDeleteFirebaseUser(authorizationCode: authCode)
            }

            do {
                try deleteAllLocalUserData(ownerProfileID: profileID, modelContext: modelContext)
            } catch {
                log.error("Local account wipe failed: \(String(describing: error), privacy: .private)")
                let wrapped = DeletionError.localDeleteFailed(String(describing: error))
                recordDeletionFailure(wrapped)
                throw wrapped
            }

            clearLocalAccountHints(appleUserIdentifier: appleUserIdentifier)
            // Journal rows for this owner are wiped with local user data; keep Logger events only.
            GoDiveSecurityEvent.record(.accountDeleted, persistToJournal: false)
            AccountSession.shared.signOut(persistSecurityEvent: false)
        } catch let deletion as DeletionError {
            if case .localDeleteFailed = deletion {
                throw deletion
            }
            recordDeletionFailure(deletion)
            throw deletion
        }
    }

    private nonisolated static func recordDeletionFailure(_ error: DeletionError) {
        GoDiveSecurityEvent.record(.accountDeleteFailed, detail: error.securityEventDetail)
        log.error(
            "Account deletion failed detail=\(error.securityEventDetail, privacy: .public): \(String(describing: error), privacy: .private)"
        )
    }

    // MARK: - Firebase / Firestore / Apple

    @MainActor
    private static func reauthenticateFirebaseIfNeeded(
        appleCredential: ASAuthorizationAppleIDCredential,
        rawNonce: String
    ) async throws {
        guard let identityToken = appleCredential.identityToken,
              let idToken = String(data: identityToken, encoding: .utf8)
        else {
            return
        }
        guard let user = Auth.auth().currentUser else {
            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: rawNonce,
                fullName: appleCredential.fullName
            )
            _ = try await Auth.auth().signIn(with: credential)
            return
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: appleCredential.fullName
        )
        _ = try await user.reauthenticate(with: credential)
    }

    @MainActor
    private static func deleteFirestoreSocialProfileIfNeeded() async throws {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        do {
            let db = Firestore.firestore()
            let userRef = db.collection("users").document(uid)
            try await userRef
                .collection("private")
                .document(GoDiveFirestoreUserProfileMapping.privateAccountDocumentID)
                .delete()
            try await userRef.delete()
        } catch {
            throw DeletionError.firestoreFailed(String(describing: error))
        }
    }

    @MainActor
    private static func revokeAppleTokenAndDeleteFirebaseUser(authorizationCode: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw DeletionError.missingFirebaseUser
        }
        do {
            try await Auth.auth().revokeToken(withAuthorizationCode: authorizationCode)
        } catch {
            throw DeletionError.appleRevokeFailed(String(describing: error))
        }
        do {
            try await user.delete()
        } catch {
            throw DeletionError.firebaseDeleteFailed(String(describing: error))
        }
    }

    // MARK: - Local SwiftData (CloudKit mirrors deletes on the user store)

    @MainActor
    static func deleteAllLocalUserData(ownerProfileID: UUID, modelContext: ModelContext) throws {
        // Tags are not cascaded from `UserProfile`; wipe them first.
        try deleteOwned(ActivityTag.self, ownerProfileID: ownerProfileID, modelContext: modelContext) { $0.ownerProfileID }

        // Profile points are local-only (no cascade from dive delete across stores).
        let ownedDiveIDs = try modelContext.fetch(FetchDescriptor<DiveActivity>())
            .filter { $0.ownerProfileID == ownerProfileID }
            .map(\.id)
        for diveID in ownedDiveIDs {
            try DiveProfilePointStore.deletePoints(for: diveID, modelContext: modelContext)
        }

        // Explicit ownership wipe covers orphans that lost the inverse relationship.
        try deleteOwned(DiveActivity.self, ownerProfileID: ownerProfileID, modelContext: modelContext) { $0.ownerProfileID }
        try deleteOwned(DiveBuddy.self, ownerProfileID: ownerProfileID, modelContext: modelContext) { $0.ownerProfileID }
        try deleteOwned(DiveTrip.self, ownerProfileID: ownerProfileID, modelContext: modelContext) { $0.ownerProfileID }
        try deleteOwned(EquipmentItem.self, ownerProfileID: ownerProfileID, modelContext: modelContext) { $0.ownerProfileID }
        try deleteOwned(Certification.self, ownerProfileID: ownerProfileID, modelContext: modelContext) { $0.ownerProfileID }
        try deleteOwned(UserDiveSite.self, ownerProfileID: ownerProfileID, modelContext: modelContext) { $0.ownerProfileID }
        try deleteOwned(UserMarineLife.self, ownerProfileID: ownerProfileID, modelContext: modelContext) { $0.ownerProfileID }
        try deleteOwned(MarineLifeUserRecord.self, ownerProfileID: ownerProfileID, modelContext: modelContext) { $0.ownerProfileID }
        try deleteOwned(UserPreferences.self, ownerProfileID: ownerProfileID, modelContext: modelContext) { $0.ownerProfileID }
        try deleteOwned(SecurityEventRecord.self, ownerProfileID: ownerProfileID, modelContext: modelContext) { $0.ownerProfileID }

        if let profile = try UserProfileStore.profile(id: ownerProfileID, modelContext: modelContext) {
            modelContext.delete(profile)
        }
        try modelContext.save()
    }

    private static func deleteOwned<T: PersistentModel>(
        _ type: T.Type,
        ownerProfileID: UUID,
        modelContext: ModelContext,
        ownerID: (T) -> UUID?
    ) throws {
        let rows = try modelContext.fetch(FetchDescriptor<T>())
        for row in rows where ownerID(row) == ownerProfileID {
            modelContext.delete(row)
        }
    }

    nonisolated static func clearLocalAccountHints(appleUserIdentifier: String) {
        UserProfileStore.cacheDisplayName(nil, forAppleUserIdentifier: appleUserIdentifier)
        ReturningAccountHints.clearAll()
        GoDiveFirestoreProfilePublishGate.clear()
        GoDiveFirestoreUserProfileMapping.clearCachedFirebaseUID()
    }
}
