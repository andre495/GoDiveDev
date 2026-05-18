import AuthenticationServices
import Foundation
import SwiftData

/// Current Sign in with Apple session and locally persisted **`UserProfile`**.
@MainActor
@Observable
final class AccountSession {
    static let shared = AccountSession()

    private(set) var currentProfile: UserProfile?
    private(set) var isRestoringSession = true

    var isSignedIn: Bool { currentProfile != nil }

    private let currentProfileIDKey = "goDiveCurrentProfileID"

    private init() {}

    func restoreSession(modelContext: ModelContext) async {
        defer { isRestoringSession = false }

        guard
            let idString = UserDefaults.standard.string(forKey: currentProfileIDKey),
            let profileID = UUID(uuidString: idString),
            let profile = try? UserProfileStore.profile(id: profileID, modelContext: modelContext)
        else {
            currentProfile = nil
            return
        }

        let state: ASAuthorizationAppleIDProvider.CredentialState
        do {
            state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: profile.appleUserIdentifier)
        } catch {
            clearPersistedSession()
            currentProfile = nil
            return
        }
        switch state {
        case .authorized:
            currentProfile = profile
            try? DiveActivityOwnership.claimUnownedDives(for: profile, modelContext: modelContext)
        default:
            clearPersistedSession()
            currentProfile = nil
        }
    }

    func completeSignIn(
        credential: ASAuthorizationAppleIDCredential,
        modelContext: ModelContext
    ) throws {
        let displayName = UserProfileStore.displayName(from: credential.fullName)
        let profile = try UserProfileStore.findOrCreateProfile(
            appleUserIdentifier: credential.user,
            displayName: displayName,
            modelContext: modelContext
        )
        try DiveActivityOwnership.claimUnownedDives(for: profile, modelContext: modelContext)
        try modelContext.save()
        persistSession(profile: profile)
        currentProfile = profile
    }

    func signOut() {
        clearPersistedSession()
        currentProfile = nil
    }

    func recordSignInFailure(_ error: Error) {
        print("Sign in with Apple failed: \(error)")
    }

    private func persistSession(profile: UserProfile) {
        UserDefaults.standard.set(profile.id.uuidString, forKey: currentProfileIDKey)
    }

    private func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: currentProfileIDKey)
    }
}
