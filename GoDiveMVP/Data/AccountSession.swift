import AuthenticationServices
import Foundation
import SwiftData
import SwiftUI

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
    /// Celebration immediately follows onboarding bulk UDDF import — defer shell prewarm.
    private(set) var celebrationFollowsBulkImport = false

    private var pendingNewAccountPermissions = false
    private var cachedSelfBuddyID: UUID?
    private var cachedSelfBuddyProfileID: UUID?

    var isSignedIn: Bool { currentProfile != nil }

    /// Signed in and past welcome / post-sign-up gates — **`ContentView`** is on screen.
    var showsMainAppShell: Bool {
        AccountSessionMainShellPresentation.showsMainAppShell(
            isSignedIn: isSignedIn,
            showsNewAccountWelcome: showsNewAccountWelcome,
            showsPostSignUpProfileSetup: showsPostSignUpProfileSetup,
            showsPostSignUpPermissions: showsPostSignUpPermissions,
            showsPostSignUpImportOffer: showsPostSignUpImportOffer,
            showsPostSignUpOnboardingImport: showsPostSignUpOnboardingImport,
            showsSignInCelebration: showsSignInCelebration
        )
    }

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
        if let merge = try? reconcileCloudKitIdentityIfNeeded(modelContext: modelContext),
           merge.didChangeCanonicalID,
           let updated = currentProfile {
            Task(priority: .utility) {
                await AppLaunchSessionValidation.validatePersistedSessionIfNeeded(
                    profileID: updated.id,
                    appleUserIdentifier: updated.appleUserIdentifier,
                    container: container
                )
            }
            return
        }
        Task(priority: .utility) {
            await AppLaunchSessionValidation.validatePersistedSessionIfNeeded(
                profileID: profile.id,
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
        var profile = try UserProfileStore.findOrCreateProfile(
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
        let merge = try UserProfileCloudKitIdentityMerge.reconcile(
            appleUserIdentifier: credential.user,
            preferredSessionProfileID: profile.id,
            modelContext: modelContext
        )
        if let canonical = try UserProfileStore.profile(id: merge.canonicalProfileID, modelContext: modelContext) {
            profile = canonical
        }
        try DiveActivityOwnership.claimUnownedDives(for: profile, modelContext: modelContext)
        try DiveBuddyOwnership.claimUnownedBuddies(for: profile, modelContext: modelContext)
        try UserPreferencesSync.syncForSignedInOwner(profile, modelContext: modelContext)

        let profileID = profile.id
        let ownedDiveCount = try modelContext.fetchCount(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate<DiveActivity> { $0.ownerProfileID == profileID }
            )
        )
        /// CloudKit may already have restored an account — don't treat that as a brand-new signup.
        let treatAsNewAccount = isNewAccount
            && merge.mergedDuplicateCount == 0
            && ownedDiveCount == 0

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

        if PostSignUpProfileSetupPresentation.shouldPresentSetup(isNewAccount: treatAsNewAccount) {
            showsPostSignUpProfileSetup = true
        } else if SignInCelebrationPresentation.shouldPresentCelebration() {
            showsSignInCelebration = true
            pendingNewAccountPermissions = treatAsNewAccount
        } else if AppNewAccountWelcomePresentation.shouldPresentWelcome(forNewAccount: treatAsNewAccount) {
            showsNewAccountWelcome = true
        } else if treatAsNewAccount {
            Task { await AppOnboardingPermissions.requestForNewAccount() }
        }
    }

    /// Re-runs Apple-ID profile merge after CloudKit import (or launch) and updates the session if needed.
    @discardableResult
    func reconcileCloudKitIdentityIfNeeded(modelContext: ModelContext) throws -> UserProfileCloudKitIdentityMerge.Outcome? {
        guard let profile = currentProfile else { return nil }
        let appleID = profile.appleUserIdentifier
        let merge = try UserProfileCloudKitIdentityMerge.reconcile(
            appleUserIdentifier: appleID,
            preferredSessionProfileID: profile.id,
            modelContext: modelContext
        )
        guard let canonical = try UserProfileStore.profile(
            id: merge.canonicalProfileID,
            modelContext: modelContext
        ) else {
            return merge
        }
        if merge.didChangeCanonicalID || currentProfile?.id != canonical.id {
            persistSession(profile: canonical)
            currentProfile = canonical
            cachedSelfBuddyID = nil
            cachedSelfBuddyProfileID = nil
            suppressNewAccountOverlaysIfReturningCloudKitAccount(canonical: canonical, modelContext: modelContext)
        }
        return merge
    }

    private func suppressNewAccountOverlaysIfReturningCloudKitAccount(
        canonical: UserProfile,
        modelContext: ModelContext
    ) {
        let id = canonical.id
        let diveCount = (try? modelContext.fetchCount(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate<DiveActivity> { $0.ownerProfileID == id }
            )
        )) ?? 0
        guard diveCount > 0 else { return }
        showsNewAccountWelcome = false
        showsPostSignUpProfileSetup = false
        showsPostSignUpPermissions = false
        showsPostSignUpImportOffer = false
        showsPostSignUpOnboardingImport = false
        pendingNewAccountPermissions = false
    }

    /// Ends the post-sign-up profile wizard and shows permissions, then import offer or celebration.
    func completePostSignUpProfileSetup() {
        guard showsPostSignUpProfileSetup else { return }
        withoutImplicitOverlayAnimation {
            showsPostSignUpProfileSetup = false
        }
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
        withoutImplicitOverlayAnimation {
            showsPostSignUpImportOffer = false
        }
        if choseImport {
            showsPostSignUpOnboardingImport = true
        } else {
            presentCelebrationOrDeferredPermissions()
        }
    }

    /// Ends the onboarding UDDF options / MacDive guide (skip or after import) and shows celebration.
    func completePostSignUpOnboardingImport(followsBulkImport: Bool = false) {
        guard showsPostSignUpOnboardingImport else { return }
        withoutImplicitOverlayAnimation {
            showsPostSignUpOnboardingImport = false
        }
        celebrationFollowsBulkImport = followsBulkImport
        presentCelebrationOrDeferredPermissions()
    }

    private func presentCelebrationOrDeferredPermissions() {
        if SignInCelebrationPresentation.shouldPresentCelebration() {
            SignInCelebrationTransitionDiagnostics.resetAnchor("presentCelebration")
            SignInCelebrationTransitionDiagnostics.mark("showsSignInCelebration_will_set_true")
            showsSignInCelebration = true
            SignInCelebrationTransitionDiagnostics.mark("showsSignInCelebration_did_set_true")
        } else if pendingNewAccountPermissions {
            pendingNewAccountPermissions = false
            Task { await AppOnboardingPermissions.requestForNewAccount() }
        }
    }

    /// Ends the post-sign-in bubble celebration and opens Home (permissions run after for new accounts).
    func completeSignInCelebration() {
        guard showsSignInCelebration else { return }
        SignInCelebrationTransitionDiagnostics.mark("completeSignInCelebration_begin")
        withoutImplicitOverlayAnimation {
            showsSignInCelebration = false
            celebrationFollowsBulkImport = false
        }
        SignInCelebrationTransitionDiagnostics.mark("completeSignInCelebration_end")
        if pendingNewAccountPermissions {
            pendingNewAccountPermissions = false
            Task {
                await Task.yield()
                await AppOnboardingPermissions.requestForNewAccount()
            }
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
        showsPostSignUpProfileSetup = false
        showsPostSignUpPermissions = false
        showsPostSignUpImportOffer = false
        showsPostSignUpOnboardingImport = false
        showsSignInCelebration = false
        celebrationFollowsBulkImport = false
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

    /// Avoid animating overlay removal + **`ContentView`** reveal in the same transaction (Instruments handoff jank).
    private func withoutImplicitOverlayAnimation(_ body: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, body)
    }
}
