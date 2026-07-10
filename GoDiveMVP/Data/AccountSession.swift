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
    /// Brand-new account — photo, DAN, certification, and profile preview before celebration.
    private(set) var showsPostSignUpProfileSetup = false
    /// Brand-new account — Contacts + Photos explainer before optional import offer.
    private(set) var showsPostSignUpPermissions = false
    /// Brand-new scuba / free-dive account — MacDive UDDF guide before celebration.
    private(set) var showsPostSignUpOnboardingImport = false
    /// Brand-new scuba / free-dive account — optional MacDive / UDDF import pitch before the guide.
    private(set) var showsPostSignUpImportOffer = false
    /// Full-screen bubble celebration after Sign in with Apple (before Home).
    private(set) var showsSignInCelebration = false
    /// One-shot Home entry animation after celebration (slide up from bottom).
    private(set) var prefersHomeRevealFromBottom = false

    private var pendingNewAccountPermissions = false
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

        if let pendingSelection = UserOnboardingActivitySelection.loadPending() {
            try UserProfileStore.applyActivitySelection(
                pendingSelection,
                to: profile,
                modelContext: modelContext
            )
            UserOnboardingActivitySelection.clearPending()
        }

        persistSession(profile: profile)
        currentProfile = profile
        cachedSelfBuddyID = nil
        cachedSelfBuddyProfileID = nil

        if PostSignUpProfileSetupPresentation.shouldPresentSetup(isNewAccount: isNewAccount) {
            showsPostSignUpProfileSetup = true
        } else if SignInCelebrationPresentation.shouldPresentCelebration() {
            showsSignInCelebration = true
            pendingNewAccountPermissions = isNewAccount
        } else if AppNewAccountWelcomePresentation.shouldPresentWelcome(forNewAccount: isNewAccount) {
            showsNewAccountWelcome = true
        } else if isNewAccount {
            Task { await AppOnboardingPermissions.requestForNewAccount() }
        }
    }

    /// Ends the post-sign-up profile wizard and shows permissions, then import offer or celebration.
    func completePostSignUpProfileSetup() {
        guard showsPostSignUpProfileSetup else { return }
        showsPostSignUpProfileSetup = false
        if PostSignUpPermissionsPresentation.shouldPresent() {
            showsPostSignUpPermissions = true
        } else {
            advanceAfterPostSignUpPermissions()
        }
    }

    /// Ends the permissions explainer (system prompts already requested) and shows import or celebration.
    func completePostSignUpPermissions() {
        guard showsPostSignUpPermissions else { return }
        showsPostSignUpPermissions = false
        advanceAfterPostSignUpPermissions()
    }

    private func advanceAfterPostSignUpPermissions() {
        if let profile = currentProfile,
           PostSignUpImportOfferPresentation.shouldPresentImportOffer(for: profile) {
            showsPostSignUpImportOffer = true
        } else {
            presentCelebrationOrDeferredPermissions()
        }
    }

    /// Ends the optional import slide — **Import dives** opens UDDF import options; **Skip** → celebration.
    func completePostSignUpImportOffer(choseImport: Bool) {
        guard showsPostSignUpImportOffer else { return }
        showsPostSignUpImportOffer = false
        if choseImport {
            showsPostSignUpOnboardingImport = true
        } else {
            presentCelebrationOrDeferredPermissions()
        }
    }

    /// Ends the onboarding UDDF options / MacDive guide (skip or after import) and shows celebration.
    func completePostSignUpOnboardingImport() {
        guard showsPostSignUpOnboardingImport else { return }
        showsPostSignUpOnboardingImport = false
        presentCelebrationOrDeferredPermissions()
    }

    private func presentCelebrationOrDeferredPermissions() {
        if SignInCelebrationPresentation.shouldPresentCelebration() {
            showsSignInCelebration = true
        } else if pendingNewAccountPermissions {
            pendingNewAccountPermissions = false
            Task { await AppOnboardingPermissions.requestForNewAccount() }
        }
    }

    /// Ends the post-sign-in bubble celebration and opens Home (permissions run after for new accounts).
    func completeSignInCelebration() {
        guard showsSignInCelebration else { return }
        showsSignInCelebration = false
        prefersHomeRevealFromBottom = true
        if pendingNewAccountPermissions {
            pendingNewAccountPermissions = false
            Task { await AppOnboardingPermissions.requestForNewAccount() }
        }
    }

    func acknowledgeHomeRevealFromBottom() {
        prefersHomeRevealFromBottom = false
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
        showsPostSignUpProfileSetup = false
        showsPostSignUpPermissions = false
        showsPostSignUpImportOffer = false
        showsPostSignUpOnboardingImport = false
        showsSignInCelebration = false
        prefersHomeRevealFromBottom = false
        pendingNewAccountPermissions = false
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
