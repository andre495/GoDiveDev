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
    /// Brand-new account after Sign in with Apple — welcome screen before Contacts + Photos prompts.
    private(set) var showsNewAccountWelcome = false

    private var cachedSelfBuddyID: UUID?
    private var cachedSelfBuddyProfileID: UUID?

    var isSignedIn: Bool { currentProfile != nil }

    private init() {}

    func restoreSession(modelContext: ModelContext) async {
        defer { isRestoringSession = false }

        let profileID = AppLaunchSessionRestorePresentation.persistedProfileID(
            storedUUIDString: UserDefaults.standard.string(
                forKey: AppLaunchSessionRestorePresentation.currentProfileIDUserDefaultsKey
            )
        )
        guard
            let profileID,
            let profile = try? UserProfileStore.profile(id: profileID, modelContext: modelContext)
        else {
            currentProfile = nil
            return
        }

        currentProfile = profile

        let container = modelContext.container
        let appleUserIdentifier = profile.appleUserIdentifier
        Task(priority: .utility) {
            await AppLaunchSessionValidation.validatePersistedSessionIfNeeded(
                profileID: profileID,
                appleUserIdentifier: appleUserIdentifier,
                container: container
            )
        }
    }

    func completeSignIn(
        credential: ASAuthorizationAppleIDCredential,
        modelContext: ModelContext
    ) throws {
        let appleProvidedName = UserProfileStore.displayName(from: credential.fullName)
        if let appleProvidedName {
            UserProfileStore.cacheDisplayName(appleProvidedName, forAppleUserIdentifier: credential.user)
        }
        let resolvedName = UserProfileStore.resolvedDisplayName(
            appleProvided: appleProvidedName,
            appleUserIdentifier: credential.user
        )
        let isNewAccount = try UserProfileStore.profile(
            appleUserIdentifier: credential.user,
            modelContext: modelContext
        ) == nil
        let profile = try UserProfileStore.findOrCreateProfile(
            appleUserIdentifier: credential.user,
            displayName: resolvedName,
            modelContext: modelContext
        )
        try UserProfileStore.applyDisplayNameFromApple(
            to: profile,
            appleProvided: appleProvidedName,
            appleUserIdentifier: credential.user,
            modelContext: modelContext
        )
        try DiveActivityOwnership.claimUnownedDives(for: profile, modelContext: modelContext)
        try DiveBuddyOwnership.claimUnownedBuddies(for: profile, modelContext: modelContext)
        persistSession(profile: profile)
        currentProfile = profile
        cachedSelfBuddyID = nil
        cachedSelfBuddyProfileID = nil

        if AppNewAccountWelcomePresentation.shouldPresentWelcome(forNewAccount: isNewAccount) {
            showsNewAccountWelcome = true
        } else if isNewAccount {
            Task { await AppOnboardingPermissions.requestForNewAccount() }
        }
    }

    /// Dismisses the welcome screen and runs the deferred onboarding permission prompts.
    func completeNewAccountWelcome() {
        guard showsNewAccountWelcome else { return }
        showsNewAccountWelcome = false
        Task { await AppOnboardingPermissions.requestForNewAccount() }
    }

    func signOut() {
        clearPersistedSession()
        currentProfile = nil
        showsNewAccountWelcome = false
        cachedSelfBuddyID = nil
        cachedSelfBuddyProfileID = nil
    }

    /// Owner roster row for the signed-in diver — resolved once per profile per session.
    func resolvedSelfBuddyID(modelContext: ModelContext) -> UUID? {
        guard let profile = currentProfile else {
            cachedSelfBuddyID = nil
            cachedSelfBuddyProfileID = nil
            return nil
        }
        if cachedSelfBuddyProfileID == profile.id {
            return cachedSelfBuddyID
        }
        let resolved = DiveBuddySelfRepresentation.resolveSelfBuddyID(
            owner: profile,
            modelContext: modelContext
        )
        cachedSelfBuddyID = resolved
        cachedSelfBuddyProfileID = profile.id
        return resolved
    }

    func recordSignInFailure(_ error: Error) {
        print("Sign in with Apple failed: \(error)")
    }

    private func persistSession(profile: UserProfile) {
        UserDefaults.standard.set(
            profile.id.uuidString,
            forKey: AppLaunchSessionRestorePresentation.currentProfileIDUserDefaultsKey
        )
    }

    private func clearPersistedSession() {
        UserDefaults.standard.removeObject(
            forKey: AppLaunchSessionRestorePresentation.currentProfileIDUserDefaultsKey
        )
    }
}
