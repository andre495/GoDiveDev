import CryptoKit
import Foundation

/// Pure mapping for Firestore social profile docs (testable without Firebase).
enum GoDiveFirestoreUserProfileMapping: Sendable {
    /// Bumped when public profile shape gained **`interests`** (+ Storage-backed **`photoURL`**).
    nonisolated static let schemaVersion = 2
    nonisolated static let privateAccountDocumentID = "account"
    nonisolated static let firebaseUIDDefaultsKey = "godive.firebase.uid"

    struct PublicProfileDraft: Equatable, Sendable {
        var displayName: String
        var handle: String
        var photoURL: String
        var interests: [String]
        var discoverable: Bool
        var schemaVersion: Int
    }

    struct PrivateAccountDraft: Equatable, Sendable {
        var appleUserIdentifier: String
    }

    nonisolated static func publicDraft(
        displayName: String,
        handle: String = "",
        photoURL: String = "",
        interests: [String] = [],
        discoverable: Bool = true
    ) -> PublicProfileDraft {
        PublicProfileDraft(
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            handle: handle.trimmingCharacters(in: .whitespacesAndNewlines),
            photoURL: photoURL.trimmingCharacters(in: .whitespacesAndNewlines),
            interests: normalizedInterests(interests),
            discoverable: discoverable,
            schemaVersion: schemaVersion
        )
    }

    nonisolated static func privateDraft(appleUserIdentifier: String) -> PrivateAccountDraft {
        PrivateAccountDraft(
            appleUserIdentifier: appleUserIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// Onboarding activity titles for Firestore **`interests`** (Scuba Diving / Free Diving / Snorkeling).
    nonisolated static func interests(
        doesScubaDiving: Bool,
        doesFreeDiving: Bool,
        doesSnorkeling: Bool
    ) -> [String] {
        var values: [String] = []
        if doesScubaDiving { values.append(UserOnboardingActivityKind.scubaDiving.title) }
        if doesFreeDiving { values.append(UserOnboardingActivityKind.freeDiving.title) }
        if doesSnorkeling { values.append(UserOnboardingActivityKind.snorkeling.title) }
        return values
    }

    nonisolated static func normalizedInterests(_ interests: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in interests {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            result.append(trimmed)
        }
        return result
    }

    /// Dictionary for Firestore `setData` (timestamps added by sync layer).
    /// Omits empty **`photoURL`** when **`includePhotoURL`** is false so merge can preserve a remote URL.
    nonisolated static func publicFields(
        from draft: PublicProfileDraft,
        includePhotoURL: Bool = true
    ) -> [String: Any] {
        var fields: [String: Any] = [
            "displayName": draft.displayName,
            "handle": draft.handle,
            "interests": draft.interests,
            "discoverable": draft.discoverable,
            "schemaVersion": draft.schemaVersion,
        ]
        if includePhotoURL {
            fields["photoURL"] = draft.photoURL
        }
        return fields
    }

    nonisolated static func privateFields(from draft: PrivateAccountDraft) -> [String: Any] {
        [
            "appleUserIdentifier": draft.appleUserIdentifier,
        ]
    }
}

/// Nonce helpers for Sign in with Apple → Firebase Auth.
enum GoDiveFirebaseAppleNonce: Sendable {
    nonisolated static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if status != errSecSuccess {
                    random = UInt8.random(in: 0 ... 255)
                }
                return random
            }
            for random in randoms {
                if remaining == 0 { continue }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    nonisolated static func sha256Nonce(_ nonce: String) -> String {
        let data = Data(nonce.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
