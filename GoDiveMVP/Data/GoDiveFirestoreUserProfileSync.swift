import Foundation
import os
import FirebaseAuth
import FirebaseFirestore

/// Upserts Firestore social profile docs (public + private Apple link).
enum GoDiveFirestoreUserProfileSync: Sendable {
    private static let log = Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "FirestoreProfile")

    enum Outcome: Equatable, Sendable {
        case skippedNotConfigured
        case skippedNotSignedIn
        case skippedDeferredUntilPhotoStep
        case upserted(uid: String, remoteDisplayName: String?)
        case failed(String)
    }

    /// Soft-fail upsert. Dive / CloudKit paths stay authoritative when this skips.
    @MainActor
    static func upsertProfile(
        displayName: String,
        appleUserIdentifier: String,
        interests: [String],
        profilePhotoJPEG: Data? = nil,
        /// When true and no JPEG upload, omit `photoURL` from the merge so an existing Storage URL is kept.
        preserveExistingPhotoURLIfNoUpload: Bool = true
    ) async -> Outcome {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else {
            log.notice("Firestore profile skip: Firebase not configured")
            return .skippedNotConfigured
        }

        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            log.notice("Firestore profile skip: no Firebase Auth currentUser")
            return .skippedNotSignedIn
        }
        UserDefaults.standard.set(uid, forKey: GoDiveFirestoreUserProfileMapping.firebaseUIDDefaultsKey)

        let privateDraft = GoDiveFirestoreUserProfileMapping.privateDraft(
            appleUserIdentifier: appleUserIdentifier
        )

        do {
            let db = Firestore.firestore()
            let userRef = db.collection("users").document(uid)
            let existing = try await userRef.getDocument()

            let remoteDisplayName = (existing.data()?["displayName"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let localName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedName: String = {
                if !localName.isEmpty, localName != UserProfileStore.defaultDisplayName {
                    return localName
                }
                if let remoteDisplayName,
                   !remoteDisplayName.isEmpty,
                   remoteDisplayName != UserProfileStore.defaultDisplayName {
                    return remoteDisplayName
                }
                return localName.isEmpty ? UserProfileStore.defaultDisplayName : localName
            }()

            var uploadedPhotoURL: String?
            if let profilePhotoJPEG, !profilePhotoJPEG.isEmpty {
                do {
                    uploadedPhotoURL = try await GoDiveFirebaseProfilePhotoStorage.uploadProfileJPEG(profilePhotoJPEG)
                } catch {
                    log.error("Profile photo upload failed: \(String(describing: error), privacy: .public)")
                    return .failed(String(describing: error))
                }
            }

            let includePhotoURL: Bool
            let photoURLValue: String
            if let uploadedPhotoURL {
                includePhotoURL = true
                photoURLValue = uploadedPhotoURL
            } else if preserveExistingPhotoURLIfNoUpload {
                includePhotoURL = false
                photoURLValue = ""
            } else {
                includePhotoURL = true
                photoURLValue = ""
            }

            let publicDraft = GoDiveFirestoreUserProfileMapping.publicDraft(
                displayName: resolvedName,
                photoURL: photoURLValue,
                interests: interests
            )
            var publicFields = GoDiveFirestoreUserProfileMapping.publicFields(
                from: publicDraft,
                includePhotoURL: includePhotoURL
            )
            publicFields["updatedAt"] = FieldValue.serverTimestamp()
            if !existing.exists {
                publicFields["createdAt"] = FieldValue.serverTimestamp()
            }
            try await userRef.setData(publicFields, merge: true)

            let privateFields = GoDiveFirestoreUserProfileMapping.privateFields(from: privateDraft)
            try await userRef
                .collection("private")
                .document(GoDiveFirestoreUserProfileMapping.privateAccountDocumentID)
                .setData(privateFields, merge: true)

            GoDiveFirestoreProfilePublishGate.clear()
            log.notice(
                "Firestore profile upserted uid=\(uid, privacy: .public) name=\(resolvedName, privacy: .public) interests=\(interests.count)"
            )
            let nameToRestore: String? = {
                guard resolvedName != UserProfileStore.defaultDisplayName else { return nil }
                if localName == UserProfileStore.defaultDisplayName || localName.isEmpty {
                    return resolvedName
                }
                return nil
            }()
            return .upserted(uid: uid, remoteDisplayName: nameToRestore ?? remoteDisplayName)
        } catch {
            let message = String(describing: error)
            log.error("Firestore profile upsert failed: \(message, privacy: .public)")
            return .failed(message)
        }
    }

    /// First social-directory write after the post-sign-up **profile photo** step (upload + interests).
    @MainActor
    static func publishAfterProfilePhotoStep(
        displayName: String,
        appleUserIdentifier: String,
        interests: [String],
        profilePhotoJPEG: Data?
    ) async -> Outcome {
        await upsertProfile(
            displayName: displayName,
            appleUserIdentifier: appleUserIdentifier,
            interests: interests,
            profilePhotoJPEG: profilePhotoJPEG,
            preserveExistingPhotoURLIfNoUpload: false
        )
    }

    /// Profile edit path: refresh `displayName` / `interests`; optionally re-upload avatar JPEG.
    @MainActor
    static func syncProfileEdits(
        displayName: String,
        appleUserIdentifier: String,
        interests: [String],
        profilePhotoJPEG: Data?,
        uploadPhoto: Bool
    ) async -> Outcome {
        await upsertProfile(
            displayName: displayName,
            appleUserIdentifier: appleUserIdentifier,
            interests: interests,
            profilePhotoJPEG: uploadPhoto ? profilePhotoJPEG : nil,
            preserveExistingPhotoURLIfNoUpload: !uploadPhoto
        )
    }

    /// Sign-in path: Auth with Apple token; optionally defer Firestore until photo step.
    @MainActor
    static func syncAfterAppleSignIn(
        identityToken: Data?,
        rawNonce: String?,
        fullName: PersonNameComponents?,
        displayName: String,
        appleUserIdentifier: String,
        interests: [String],
        deferProfileDocumentWrite: Bool
    ) async -> Outcome {
        let auth = await GoDiveFirebaseAuthSession.signInWithApple(
            identityToken: identityToken,
            rawNonce: rawNonce,
            fullName: fullName
        )
        switch auth {
        case .skippedNotConfigured:
            log.notice("Social sync after Apple: Auth not configured")
            return .skippedNotConfigured
        case .skippedMissingIdentityToken:
            log.notice("Social sync after Apple: missing token; trying existing Auth session")
            if deferProfileDocumentWrite {
                GoDiveFirestoreProfilePublishGate.markDeferredUntilPhotoStep()
                return .skippedDeferredUntilPhotoStep
            }
            return await upsertProfile(
                displayName: displayName,
                appleUserIdentifier: appleUserIdentifier,
                interests: interests
            )
        case .failed(let message):
            log.error("Social sync after Apple: Auth failed — \(message, privacy: .public)")
            return .failed(message)
        case .signedIn, .alreadySignedIn:
            if deferProfileDocumentWrite {
                GoDiveFirestoreProfilePublishGate.markDeferredUntilPhotoStep()
                log.notice("Social sync after Apple: Auth ok; deferring Firestore until photo step")
                return .skippedDeferredUntilPhotoStep
            }
            return await upsertProfile(
                displayName: displayName,
                appleUserIdentifier: appleUserIdentifier,
                interests: interests
            )
        }
    }

    /// Launch / idle: upsert when Firebase Auth session already exists (skips while photo-step deferral is active).
    @MainActor
    static func syncIfAuthenticated(
        displayName: String,
        appleUserIdentifier: String,
        interests: [String]
    ) async -> Outcome {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return .skippedNotConfigured }
        guard Auth.auth().currentUser != nil else {
            return .skippedNotSignedIn
        }
        if GoDiveFirestoreProfilePublishGate.isDeferredUntilPhotoStep() {
            log.notice("Firestore profile skip: deferred until photo step")
            return .skippedDeferredUntilPhotoStep
        }
        return await upsertProfile(
            displayName: displayName,
            appleUserIdentifier: appleUserIdentifier,
            interests: interests
        )
    }
}
