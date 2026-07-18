import AuthenticationServices
import Foundation
import SwiftData
import SwiftUI
import FirebaseAuth

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
        ReturningAccountHints.remember(profile: profile)

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
        rawNonce: String? = nil,
        modelContext: ModelContext
    ) throws {
        let appleUserID = credential.user
        let appleProvidedName = UserProfileStore.displayName(from: credential.fullName)
        if let appleProvidedName {
            UserProfileStore.cacheDisplayName(appleProvidedName, forAppleUserIdentifier: appleUserID)
        }
        let resolvedName = UserProfileStore.resolvedDisplayName(
            appleProvided: appleProvidedName,
            appleUserIdentifier: appleUserID
        )

        let existingBeforeSignIn = try resolveExistingProfile(
            appleUserIdentifier: appleUserID,
            modelContext: modelContext
        )
        let profileDidExistLocally = existingBeforeSignIn != nil

        var profile = try UserProfileStore.findOrCreateProfile(
            appleUserIdentifier: appleUserID,
            displayName: resolvedName,
            modelContext: modelContext
        )
        try UserProfileStore.applyDisplayNameFromApple(
            to: profile,
            appleProvided: appleProvidedName,
            appleUserIdentifier: appleUserID,
            modelContext: modelContext
        )
        let merge = try UserProfileCloudKitIdentityMerge.reconcile(
            appleUserIdentifier: appleUserID,
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
        /// CloudKit / prior device session — don't re-run brand-new signup chrome for returning Apple IDs.
        let treatAsNewAccount = ReturningAccountHints.treatAsNewAccount(
            profileDidExistLocally: profileDidExistLocally,
            mergedDuplicateCount: merge.mergedDuplicateCount,
            ownedDiveCount: ownedDiveCount,
            appleUserIdentifier: appleUserID
        )

        if let pendingSelection = UserOnboardingActivitySelection.loadPending() {
            try UserProfileStore.applyActivitySelection(
                pendingSelection,
                to: profile,
                modelContext: modelContext
            )
            UserOnboardingActivitySelection.clearPending()
        }

        try modelContext.save()
        persistSession(profile: profile)
        currentProfile = profile
        cachedSelfBuddyID = nil
        cachedSelfBuddyProfileID = nil

        let identityToken = credential.identityToken
        let appleUserIdentifier = profile.appleUserIdentifier
        let displayName = profile.displayName
        let fullName = credential.fullName
        let interests = GoDiveFirestoreUserProfileMapping.interests(
            doesScubaDiving: profile.doesScubaDiving,
            doesFreeDiving: profile.doesFreeDiving,
            doesSnorkeling: profile.doesSnorkeling
        )
        let deferFirestoreUpsert = PostSignUpProfileSetupPresentation.shouldPresentSetup(
            isNewAccount: treatAsNewAccount
        )
        Task(priority: .utility) {
            let outcome = await GoDiveFirestoreUserProfileSync.syncAfterAppleSignIn(
                identityToken: identityToken,
                rawNonce: rawNonce,
                fullName: fullName,
                displayName: displayName,
                appleUserIdentifier: appleUserIdentifier,
                interests: interests,
                deferProfileDocumentWrite: deferFirestoreUpsert
            )
            if case let .upserted(_, remoteDisplayName) = outcome {
                await MainActor.run {
                    AccountSession.shared.applyRemoteDisplayNameIfNeeded(
                        profileID: profileID,
                        remoteDisplayName: remoteDisplayName,
                        modelContext: modelContext
                    )
                }
            }
        }

        if deferFirestoreUpsert {
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

    /// Local profile for this Apple ID, including the last signed-in row remembered across sign-out.
    private func resolveExistingProfile(
        appleUserIdentifier: String,
        modelContext: ModelContext
    ) throws -> UserProfile? {
        if let existing = try UserProfileStore.profile(
            appleUserIdentifier: appleUserIdentifier,
            modelContext: modelContext
        ) {
            return existing
        }
        if let rememberedID = ReturningAccountHints.rememberedProfileID(
            forAppleUserIdentifier: appleUserIdentifier
        ),
            let remembered = try UserProfileStore.profile(id: rememberedID, modelContext: modelContext),
            remembered.appleUserIdentifier == appleUserIdentifier
        {
            return remembered
        }
        return nil
    }

    /// Applies a Firestore / remote display name when the local profile is still the placeholder.
    func applyRemoteDisplayNameIfNeeded(
        profileID: UUID,
        remoteDisplayName: String?,
        modelContext: ModelContext
    ) {
        guard let live = try? UserProfileStore.profile(id: profileID, modelContext: modelContext) else {
            return
        }
        let didApply = (try? UserProfileStore.applyRestoredDisplayNameIfNeeded(
            to: live,
            restoredName: remoteDisplayName,
            modelContext: modelContext
        )) ?? false
        guard didApply else { return }
        if currentProfile?.id == live.id {
            currentProfile = live
        }
        ReturningAccountHints.remember(profile: live)
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
        if GoDiveFirestoreProfilePublishGate.isDeferredUntilPhotoStep() {
            publishFirestoreSocialProfileAfterPhotoStep()
        }
        withoutImplicitOverlayAnimation {
            showsPostSignUpProfileSetup = false
        }
        if PostSignUpPermissionsPresentation.shouldPresent() {
            showsPostSignUpPermissions = true
        } else {
            advanceAfterPostSignUpPermissions()
        }
    }

    /// First Firestore social-directory write after the profile-photo step (or skip), including Storage avatar when present.
    func publishFirestoreSocialProfileAfterPhotoStep() {
        guard let profile = currentProfile else { return }
        let displayName = profile.displayName
        let appleUserIdentifier = profile.appleUserIdentifier
        let interests = GoDiveFirestoreUserProfileMapping.interests(
            doesScubaDiving: profile.doesScubaDiving,
            doesFreeDiving: profile.doesFreeDiving,
            doesSnorkeling: profile.doesSnorkeling
        )
        let photoJPEG = profile.profilePhoto
        Task(priority: .utility) {
            _ = await GoDiveFirestoreUserProfileSync.publishAfterProfilePhotoStep(
                displayName: displayName,
                appleUserIdentifier: appleUserIdentifier,
                interests: interests,
                profilePhotoJPEG: photoJPEG
            )
        }
    }

    /// Pushes display name and/or a new profile photo to Firestore / Storage after Profile edits.
    /// No-ops while the post-sign-up photo-step deferral is still active (initial publish owns that write).
    func pushFirestoreSocialProfileEdits(uploadPhoto: Bool) {
        guard GoDiveFirestoreProfileEditSync.shouldSyncEdits(
            isDeferredUntilPhotoStep: GoDiveFirestoreProfilePublishGate.isDeferredUntilPhotoStep()
        ) else { return }
        guard let profile = currentProfile else { return }
        let displayName = profile.displayName
        let appleUserIdentifier = profile.appleUserIdentifier
        let interests = GoDiveFirestoreUserProfileMapping.interests(
            doesScubaDiving: profile.doesScubaDiving,
            doesFreeDiving: profile.doesFreeDiving,
            doesSnorkeling: profile.doesSnorkeling
        )
        let photoJPEG = uploadPhoto ? profile.profilePhoto : nil
        Task(priority: .utility) {
            _ = await GoDiveFirestoreUserProfileSync.syncProfileEdits(
                displayName: displayName,
                appleUserIdentifier: appleUserIdentifier,
                interests: interests,
                profilePhotoJPEG: photoJPEG,
                uploadPhoto: uploadPhoto
            )
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
        UserDefaults.standard.removeObject(forKey: GoDiveFirestoreUserProfileMapping.firebaseUIDDefaultsKey)
        GoDiveFirestoreProfilePublishGate.clear()
        if GoDiveFirebaseBootstrap.isConfigured {
            try? Auth.auth().signOut()
        }
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
        ReturningAccountHints.remember(profile: profile)
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
