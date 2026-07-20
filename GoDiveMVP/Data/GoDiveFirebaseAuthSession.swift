import AuthenticationServices
import Foundation
import os
import FirebaseAuth

/// Signs into Firebase Auth with an Apple identity token (soft-fail when Firebase is off).
enum GoDiveFirebaseAuthSession: Sendable {
    private static let log = Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "FirebaseAuth")

    enum Outcome: Equatable, Sendable {
        case skippedNotConfigured
        case skippedMissingIdentityToken
        case signedIn(uid: String)
        case alreadySignedIn(uid: String)
        case failed(String)
    }

    @MainActor
    static func signInWithApple(
        identityToken: Data?,
        rawNonce: String?,
        fullName: PersonNameComponents?
    ) async -> Outcome {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else {
            log.notice("Firebase Auth skip: Bootstrap.isConfigured == false (see FirebaseBootstrap logs)")
            return .skippedNotConfigured
        }

        // Prefer a fresh Apple token when available so provider misconfig surfaces on each Sign in.
        let hasAppleCredential = identityToken != nil && !(rawNonce ?? "").isEmpty
        if !hasAppleCredential, let existing = Auth.auth().currentUser {
            GoDiveFirestoreUserProfileMapping.saveCachedFirebaseUID(existing.uid)
            log.notice("Firebase Auth already signed in (uid redacted)")
            return .alreadySignedIn(uid: existing.uid)
        }

        guard let identityToken,
              let idToken = String(data: identityToken, encoding: .utf8),
              let rawNonce,
              !rawNonce.isEmpty
        else {
            log.notice("Firebase Auth skip: missing identityToken or nonce")
            return .skippedMissingIdentityToken
        }

        do {
            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: rawNonce,
                fullName: fullName
            )
            let result = try await Auth.auth().signIn(with: credential)
            let uid = result.user.uid
            GoDiveFirestoreUserProfileMapping.saveCachedFirebaseUID(uid)
            log.notice("Firebase Auth signed in (uid redacted)")
            GoDiveSecurityEvent.record(.authSucceeded, detail: "firebase")
            return .signedIn(uid: uid)
        } catch {
            log.error("Firebase Auth failed: \(String(describing: error), privacy: .private)")
            GoDiveSecurityEvent.record(.authFailed, detail: "firebase")
            return .failed("Sign-in could not be completed.")
        }
    }

    /// Firebase Auth persistence — use after prior Apple→Firebase link.
    @MainActor
    static func currentFirebaseUID() -> String? {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return nil }
        if let uid = Auth.auth().currentUser?.uid {
            GoDiveFirestoreUserProfileMapping.saveCachedFirebaseUID(uid)
            return uid
        }
        return GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID()
    }
}
