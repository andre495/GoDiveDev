import AuthenticationServices
import Foundation
import os
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
    /// Brand-new account that skipped welcome interests — activity picker before profile photo.
    private(set) var showsPostSignUpInterests = false
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
    /// Firebase + iCloud population after sign-in / session restore (keeps launch overlay up).
    private(set) var isPopulatingRemoteAccountData = false
    /// Returning user on a local-only store — private CloudKit reconnect is scheduled for the next cold launch.
    private(set) var pendingICloudDiveLogReconnectOnNextLaunch = false

    private var pendingNewAccountPermissions = false
    private var cachedSelfBuddyID: UUID?
    private var cachedSelfBuddyProfileID: UUID?

    /// Production shell registers the live store so sign-in can re-attach **`UserProfile`** after CloudKit reconnect.
    weak var activeModelContainer: ModelContainer?

    /// Invoked by **`AccountRemoteDataPopulation`** to reopen the user store with private CloudKit.
    var cloudKitContainerReconnectHandler: (@MainActor () async -> Void)?

    private var remoteAccountPopulationDepth = 0

    var isSignedIn: Bool { currentProfile != nil && !isPopulatingRemoteAccountData }

    /// Signed in and past welcome / post-sign-up gates — **`ContentView`** is on screen.
    var showsMainAppShell: Bool {
        AccountSessionMainShellPresentation.showsMainAppShell(
            isSignedIn: isSignedIn,
            showsNewAccountWelcome: showsNewAccountWelcome,
            showsPostSignUpInterests: showsPostSignUpInterests,
            showsPostSignUpProfileSetup: showsPostSignUpProfileSetup,
            showsPostSignUpPermissions: showsPostSignUpPermissions,
            showsPostSignUpImportOffer: showsPostSignUpImportOffer,
            showsPostSignUpOnboardingImport: showsPostSignUpOnboardingImport,
            showsSignInCelebration: showsSignInCelebration
        )
    }

    private init() {}

    func restoreSession(modelContext: ModelContext) async {
        defer {
            isRestoringSession = false
            endLaunchBlockingPopulationIfStuck()
        }

        await waitForCloudKitContainerReconnectHandler()

        let context = activeModelContainer?.mainContext ?? modelContext

        let appleID = GoDiveKeychainStore.string(for: .lastAppleUserIdentifier)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !appleID.isEmpty else {
            if let profileID = AppLaunchSessionRestorePresentation.loadPersistedProfileID(),
               let profile = try? UserProfileStore.profile(id: profileID, modelContext: context)
            {
                currentProfile = profile
                ReturningAccountHints.remember(profile: profile)
            } else {
                currentProfile = nil
            }
            return
        }

        let preferredID = AppLaunchSessionRestorePresentation.loadPersistedProfileID()
            ?? ReturningAccountHints.rememberedProfileID(forAppleUserIdentifier: appleID)
        guard let preferredID else {
            currentProfile = nil
            return
        }

        let launchWait = AccountSessionProfileResolution.launchImportTimeoutSeconds
        if let attached = try? await attachSessionProfile(
            preferredProfileID: preferredID,
            appleUserIdentifier: appleID,
            fallbackContext: context,
            waitForCloudKitImport: true,
            importTimeoutSeconds: launchWait
        ) {
            persistSession(profile: attached)
            _ = try? reconcileCloudKitIdentityIfNeeded(modelContext: context)
        } else {
            currentProfile = nil
        }

        let profileIDForDeferred = currentProfile?.id ?? preferredID
        Task { @MainActor in
            async let population: Void = self.runDeferredSessionRestorePopulation(
                preferredProfileID: profileIDForDeferred,
                appleUserIdentifier: appleID,
                modelContext: modelContext
            )
            async let cloudKit: Void = self.syncCloudKitDiveLogIntoSession(
                preferredProfileID: profileIDForDeferred,
                appleUserIdentifier: appleID,
                modelContext: modelContext
            )
            _ = await (population, cloudKit)
        }
    }

    /// Firebase + CloudKit merge after the splash dismisses — does not block **`AppLaunchOverlay`**.
    private func runDeferredSessionRestorePopulation(
        preferredProfileID: UUID,
        appleUserIdentifier: String,
        modelContext: ModelContext
    ) async {
        var context = activeModelContainer?.mainContext ?? modelContext

        await AccountRemoteDataPopulation.populateSignedInAccount(
            trigger: .sessionRestore,
            modelContext: context,
            treatAsNewAccount: false,
            mergedDuplicateCount: 0,
            holdsLaunchOverlay: false
        )

        context = activeModelContainer?.mainContext ?? modelContext

        if let attached = try? await attachSessionProfile(
            preferredProfileID: preferredProfileID,
            appleUserIdentifier: appleUserIdentifier,
            fallbackContext: context,
            waitForCloudKitImport: false
        ) {
            persistSession(profile: attached)
            _ = try? reconcileCloudKitIdentityIfNeeded(modelContext: context)
        }
    }

    /// Polls private CloudKit import, merges Apple-ID profile twins, and re-attaches the session to
    /// whichever profile owns dives/snorkels (fixes an empty Logbook after reinstall / sign-in).
    @MainActor
    func syncCloudKitDiveLogIntoSession(
        preferredProfileID: UUID,
        appleUserIdentifier: String,
        modelContext: ModelContext,
        waitForActivitiesSeconds: Int = AccountSessionProfileResolution.defaultImportTimeoutSeconds
    ) async {
        let appleID = appleUserIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appleID.isEmpty else { return }

        var context = activeModelContainer?.mainContext ?? modelContext
        let deadline = ContinuousClock.now + .seconds(waitForActivitiesSeconds)

        while ContinuousClock.now < deadline {
            guard !Task.isCancelled else { return }
            context.processPendingChanges()
            _ = try? reconcileCloudKitIdentityIfNeeded(modelContext: context)

            let totalForAppleID = AccountSessionProfileResolution.totalOwnedActivityCount(
                appleUserIdentifier: appleID,
                modelContext: context
            )
            if totalForAppleID > 0 {
                if let attached = try? await attachSessionProfile(
                    preferredProfileID: preferredProfileID,
                    appleUserIdentifier: appleID,
                    fallbackContext: context,
                    waitForCloudKitImport: false
                ) {
                    persistSession(profile: attached)
                    _ = try? reconcileCloudKitIdentityIfNeeded(modelContext: context)
                    if let owner = currentProfile {
                        _ = try? DiveActivityOwnership.claimUnownedDives(
                            for: owner,
                            modelContext: context
                        )
                        _ = try? SnorkelActivityOwnership.claimUnownedSnorkels(
                            for: owner,
                            modelContext: context
                        )
                        _ = try? DiveBuddyOwnership.claimUnownedBuddies(
                            for: owner,
                            modelContext: context
                        )
                    }
                }
                break
            }

            await GoDiveCloudKitPrivateImportNotification.waitForImportOrTimeout(
                milliseconds: GoDiveCloudKitPrivateImportNotification.defaultPollIntervalMilliseconds
            )
            context = activeModelContainer?.mainContext ?? modelContext
        }

        if let container = activeModelContainer,
           AccountSessionProfileResolution.totalOwnedActivityCount(
               appleUserIdentifier: appleID,
               modelContext: context
           ) == 0
        {
            AccountSessionCloudKitIdentityObserver.schedulePostSignInReconcileRetries(
                container: container
            )
        }
    }

    /// After Sign in with Apple scheduled iCloud — reload stores once Home is visible, then import + merge.
    func finishAfterScheduledCloudKitReconnect(modelContext: ModelContext) async {
        var context = activeModelContainer?.mainContext ?? modelContext
        let appleID = GoDiveKeychainStore.string(for: .lastAppleUserIdentifier)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let preferredID = AppLaunchSessionRestorePresentation.loadPersistedProfileID()
            ?? ReturningAccountHints.rememberedProfileID(forAppleUserIdentifier: appleID)
            ?? UUID()
        guard !appleID.isEmpty else {
            pendingICloudDiveLogReconnectOnNextLaunch = false
            return
        }

        // Wait for CloudKit dive/snorkel import before attaching the session + merging twins.
        // Profile rows often arrive before activities; merging too early orphans the log.
        _ = await AccountSessionProfileResolution.waitForOwnedActivities(
            appleUserIdentifier: appleID,
            modelContext: context,
            timeoutSeconds: 90
        )

        await AccountRemoteDataPopulation.populateSignedInAccount(
            trigger: .sessionRestore,
            modelContext: context,
            skipCloudKitReconnect: true,
            treatAsNewAccount: false,
            mergedDuplicateCount: 0,
            holdsLaunchOverlay: false
        )

        context = activeModelContainer?.mainContext ?? modelContext

        if let attached = try? await attachSessionProfile(
            preferredProfileID: preferredID,
            appleUserIdentifier: appleID,
            fallbackContext: context,
            waitForCloudKitImport: true,
            importTimeoutSeconds: AccountSessionProfileResolution.defaultImportTimeoutSeconds
        ) {
            persistSession(profile: attached)
            _ = try? reconcileCloudKitIdentityIfNeeded(modelContext: context)
            // Second pass after attach — import may have landed more rows during population.
            _ = await AccountSessionProfileResolution.waitForOwnedActivities(
                appleUserIdentifier: appleID,
                modelContext: context,
                timeoutSeconds: 15
            )
            context = activeModelContainer?.mainContext ?? context
            if let refreshed = try? await attachSessionProfile(
                preferredProfileID: attached.id,
                appleUserIdentifier: appleID,
                fallbackContext: context,
                waitForCloudKitImport: false
            ) {
                persistSession(profile: refreshed)
                _ = try? reconcileCloudKitIdentityIfNeeded(modelContext: context)
                suppressNewAccountOverlaysIfReturningCloudKitAccount(
                    canonical: refreshed,
                    mergedDuplicateCount: 0,
                    modelContext: context
                )
            } else {
                suppressNewAccountOverlaysIfReturningCloudKitAccount(
                    canonical: attached,
                    mergedDuplicateCount: 0,
                    modelContext: context
                )
            }
        }
        pendingICloudDiveLogReconnectOnNextLaunch = false
    }

    func registerActiveModelContainer(_ container: ModelContainer) {
        activeModelContainer = container
    }

    func completeSignIn(
        credential: ASAuthorizationAppleIDCredential,
        rawNonce: String? = nil,
        modelContext: ModelContext
    ) async throws {
        beginRemoteAccountPopulation()
        defer { endRemoteAccountPopulation() }

        let appleUserID = credential.user
        let workingContext = activeModelContainer?.mainContext ?? modelContext

        if AccountRemoteDataPopulation.shouldReconnectBeforeSignIn(
            appleUserIdentifier: appleUserID,
            modelContext: workingContext
        ) {
            AppSwiftDataDualStoreFactory.scheduleReconnectPrivateCloudKitOnNextLaunch()
            pendingICloudDiveLogReconnectOnNextLaunch = true
        }

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
            modelContext: workingContext
        )
        let profileDidExistLocally = existingBeforeSignIn != nil

        var profile = try UserProfileStore.findOrCreateProfile(
            appleUserIdentifier: appleUserID,
            displayName: resolvedName,
            modelContext: workingContext
        )
        try UserProfileStore.applyDisplayNameFromApple(
            to: profile,
            appleProvided: appleProvidedName,
            appleUserIdentifier: appleUserID,
            modelContext: workingContext
        )
        let merge = try UserProfileCloudKitIdentityMerge.reconcile(
            appleUserIdentifier: appleUserID,
            preferredSessionProfileID: profile.id,
            modelContext: workingContext
        )
        if let canonical = try UserProfileStore.profile(id: merge.canonicalProfileID, modelContext: workingContext) {
            profile = canonical
        }
        try DiveActivityOwnership.claimUnownedDives(for: profile, modelContext: workingContext)
        try SnorkelActivityOwnership.claimUnownedSnorkels(for: profile, modelContext: workingContext)
        try DiveBuddyOwnership.claimUnownedBuddies(for: profile, modelContext: workingContext)
        try UserPreferencesSync.syncForSignedInOwner(profile, modelContext: workingContext)

        let profileID = profile.id
        let ownedDiveCount = try workingContext.fetchCount(
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

        let pendingSelection = UserOnboardingActivitySelection.loadPending()
        let hadPendingWelcomeInterests = pendingSelection?.hasAnySelection == true
        if let pendingSelection, hadPendingWelcomeInterests {
            try UserProfileStore.applyActivitySelection(
                pendingSelection,
                to: profile,
                modelContext: workingContext
            )
        }
        UserOnboardingActivitySelection.clearPending()

        try workingContext.save()
        cachedSelfBuddyID = nil
        cachedSelfBuddyProfileID = nil
        ReturningAccountHints.remember(profile: profile)
        GoDiveSecurityEvent.record(.authSucceeded, detail: "siwa")

        let appleUserIdentifier = profile.appleUserIdentifier
        let interests = GoDiveFirestoreUserProfileMapping.interests(
            doesScubaDiving: profile.doesScubaDiving,
            doesFreeDiving: profile.doesFreeDiving,
            doesSnorkeling: profile.doesSnorkeling
        )
        let deferFirestoreUpsert = PostSignUpProfileSetupPresentation.shouldPresentSetup(
            isNewAccount: treatAsNewAccount
        )
        let signInPopulation = AccountRemoteDataPopulation.SignInWithAppleRequest(
            identityToken: credential.identityToken,
            rawNonce: rawNonce,
            fullName: credential.fullName,
            displayName: profile.displayName,
            appleUserIdentifier: appleUserIdentifier,
            interests: interests,
            profileID: profileID,
            deferFirestoreProfileDocumentWrite: deferFirestoreUpsert
        )
        let populationContext = activeModelContainer?.mainContext ?? workingContext
        async let cloudKitSync: Void = syncCloudKitDiveLogIntoSession(
            preferredProfileID: profileID,
            appleUserIdentifier: appleUserIdentifier,
            modelContext: populationContext
        )
        await AccountRemoteDataPopulation.populateSignedInAccount(
            trigger: .signInWithApple,
            modelContext: populationContext,
            signInWithApple: signInPopulation,
            treatAsNewAccount: treatAsNewAccount,
            mergedDuplicateCount: merge.mergedDuplicateCount
        )
        let attachContext = activeModelContainer?.mainContext ?? workingContext
        try await attachSessionProfile(
            preferredProfileID: profileID,
            appleUserIdentifier: appleUserIdentifier,
            fallbackContext: attachContext,
            waitForCloudKitImport: !treatAsNewAccount && !pendingICloudDiveLogReconnectOnNextLaunch
        )
        persistSession(profile: currentProfile ?? profile)
        await cloudKitSync

        if deferFirestoreUpsert {
            if PostSignUpInterestsPresentation.shouldPresent(
                hadPendingWelcomeInterests: hadPendingWelcomeInterests
            ) {
                showsPostSignUpInterests = true
            } else {
                showsPostSignUpProfileSetup = true
            }
            // CloudKit may still be downloading the existing Apple-ID profile + dives.
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
        modelContext.processPendingChanges()
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
        let sessionNeedsSwitch = currentProfile?.id != canonical.id
        if merge.didChangeCanonicalID || sessionNeedsSwitch {
            persistSession(profile: canonical)
            currentProfile = canonical
            cachedSelfBuddyID = nil
            cachedSelfBuddyProfileID = nil
        }
        // Always evaluate overlays after a merge attempt — CloudKit may have attached dives to the
        // canonical row without changing the session UUID (or switched us onto the restored profile).
        suppressNewAccountOverlaysIfReturningCloudKitAccount(
            canonical: canonical,
            mergedDuplicateCount: merge.mergedDuplicateCount,
            modelContext: modelContext
        )
        return merge
    }

    private func suppressNewAccountOverlaysIfReturningCloudKitAccount(
        canonical: UserProfile,
        mergedDuplicateCount: Int,
        modelContext: ModelContext
    ) {
        let id = canonical.id
        let diveCount = (try? modelContext.fetchCount(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate<DiveActivity> { $0.ownerProfileID == id }
            )
        )) ?? 0
        let snorkelCount = (try? modelContext.fetchCount(
            FetchDescriptor<SnorkelActivity>(
                predicate: #Predicate<SnorkelActivity> { $0.ownerProfileID == id }
            )
        )) ?? 0
        // Activities on the canonical profile, or a CloudKit duplicate merge, prove this is not a cold signup.
        guard diveCount > 0 || snorkelCount > 0 || mergedDuplicateCount > 0 else { return }
        showsNewAccountWelcome = false
        showsPostSignUpInterests = false
        showsPostSignUpProfileSetup = false
        showsPostSignUpPermissions = false
        showsPostSignUpImportOffer = false
        showsPostSignUpOnboardingImport = false
        pendingNewAccountPermissions = false
        ReturningAccountHints.remember(profile: canonical)
    }

    /// Ends the post-sign-up interests picker and shows profile photo setup.
    func completePostSignUpInterests(
        selection: UserOnboardingActivitySelection,
        modelContext: ModelContext
    ) throws {
        guard showsPostSignUpInterests else { return }
        guard let profile = currentProfile else { return }
        try UserProfileStore.applyActivitySelection(
            selection,
            to: profile,
            modelContext: modelContext
        )
        withoutImplicitOverlayAnimation {
            showsPostSignUpInterests = false
            showsPostSignUpProfileSetup = true
        }
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

    /// - Parameter persistSecurityEvent: Pass **`false`** when the account wipe already cleared the journal
    ///   (account delete) so we do not recreate rows for a deleted owner.
    func acknowledgePendingICloudDiveLogReconnectReminder() {
        pendingICloudDiveLogReconnectOnNextLaunch = false
    }

    func signOut(persistSecurityEvent: Bool = true) {
        let ownerID = AppLaunchSessionRestorePresentation.loadPersistedProfileID()
        clearPersistedSession()
        currentProfile = nil
        showsNewAccountWelcome = false
        showsPostSignUpInterests = false
        showsPostSignUpProfileSetup = false
        showsPostSignUpPermissions = false
        showsPostSignUpImportOffer = false
        showsPostSignUpOnboardingImport = false
        showsSignInCelebration = false
        celebrationFollowsBulkImport = false
        pendingICloudDiveLogReconnectOnNextLaunch = false
        pendingNewAccountPermissions = false
        cachedSelfBuddyID = nil
        cachedSelfBuddyProfileID = nil
        GoDiveFirestoreUserProfileMapping.clearCachedFirebaseUID()
        GoDiveFirestoreProfilePublishGate.clear()
        GoDiveFriendShareRefreshCoordinator.stopObservingSaves()
        if GoDiveFirebaseBootstrap.isConfigured {
            Task { @MainActor in
                await GoDiveFirebaseCloudMessaging.removeStoredTokenOnSignOut()
                try? Auth.auth().signOut()
            }
        }
        GoDiveSecurityEvent.record(
            .signOut,
            ownerProfileID: ownerID,
            persistToJournal: persistSecurityEvent
        )
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

    private static let authLog = Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "AccountSession")

    /// Generic failure recording — does not surface credential details to the UI.
    func recordSignInFailure(_ error: Error) {
        Self.authLog.error("Sign in with Apple failed: \(String(describing: error), privacy: .private)")
        GoDiveSecurityEvent.record(.authFailed, detail: "siwa")
    }

    func beginRemoteAccountPopulation() {
        remoteAccountPopulationDepth += 1
        isPopulatingRemoteAccountData = true
    }

    func endRemoteAccountPopulation() {
        remoteAccountPopulationDepth = max(0, remoteAccountPopulationDepth - 1)
        if remoteAccountPopulationDepth == 0 {
            isPopulatingRemoteAccountData = false
        }
    }

    func requestModelContainerCloudKitReconnect() async {
        for _ in 0 ..< 15 {
            if let cloudKitContainerReconnectHandler {
                currentProfile = nil
                cachedSelfBuddyID = nil
                cachedSelfBuddyProfileID = nil
                await cloudKitContainerReconnectHandler()
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    /// Session restore can start in the same frame as **`ProductionAppRoot`** — wait briefly for the handler.
    private func waitForCloudKitContainerReconnectHandler() async {
        guard cloudKitContainerReconnectHandler == nil else { return }
        for _ in 0 ..< 15 {
            if cloudKitContainerReconnectHandler != nil { return }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    /// Safety valve if population depth was left non-zero after a cancelled reconnect path.
    private func endLaunchBlockingPopulationIfStuck() {
        guard isPopulatingRemoteAccountData else { return }
        remoteAccountPopulationDepth = 0
        isPopulatingRemoteAccountData = false
    }

    @discardableResult
    func attachSessionProfile(
        preferredProfileID: UUID,
        appleUserIdentifier: String,
        fallbackContext: ModelContext,
        waitForCloudKitImport: Bool,
        importTimeoutSeconds: Int = AccountSessionProfileResolution.defaultImportTimeoutSeconds
    ) async throws -> UserProfile {
        let context = activeModelContainer?.mainContext ?? fallbackContext
        _ = try? reconcileCloudKitIdentityIfNeeded(modelContext: context)
        guard let profile = await AccountSessionProfileResolution.resolve(
            preferredProfileID: preferredProfileID,
            appleUserIdentifier: appleUserIdentifier,
            modelContext: context,
            waitForCloudKitImport: waitForCloudKitImport,
            importTimeoutSeconds: importTimeoutSeconds
        ) else {
            throw AttachSessionProfileError.profileMissingAfterPopulation
        }
        currentProfile = profile
        ReturningAccountHints.remember(profile: profile)
        return profile
    }

    enum AttachSessionProfileError: Error {
        case profileMissingAfterPopulation
    }

    /// Re-attach session + merge after SwiftData re-opened with private CloudKit.
    func rebindAfterModelContainerReconnect(modelContext: ModelContext) async {
        let appleID = GoDiveKeychainStore.string(for: .lastAppleUserIdentifier)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let preferredID = AppLaunchSessionRestorePresentation.loadPersistedProfileID()
            ?? ReturningAccountHints.rememberedProfileID(forAppleUserIdentifier: appleID ?? "")

        guard let appleID, !appleID.isEmpty else {
            if let preferredID {
                _ = try? await attachSessionProfile(
                    preferredProfileID: preferredID,
                    appleUserIdentifier: "",
                    fallbackContext: modelContext,
                    waitForCloudKitImport: true
                )
            } else {
                currentProfile = nil
            }
            return
        }

        let profileID = preferredID ?? UUID()
        _ = try? await attachSessionProfile(
            preferredProfileID: profileID,
            appleUserIdentifier: appleID,
            fallbackContext: modelContext,
            waitForCloudKitImport: true
        )
    }

    nonisolated static let signInFailureUserMessage = "Sign-in could not be completed. Please try again."

    private func persistSession(profile: UserProfile) {
        AppLaunchSessionRestorePresentation.savePersistedProfileID(profile.id)
        ReturningAccountHints.remember(profile: profile)
    }

    private func clearPersistedSession() {
        AppLaunchSessionRestorePresentation.clearPersistedProfileID()
    }

    /// Avoid animating overlay removal + **`ContentView`** reveal in the same transaction (Instruments handoff jank).
    private func withoutImplicitOverlayAnimation(_ body: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, body)
    }
}
