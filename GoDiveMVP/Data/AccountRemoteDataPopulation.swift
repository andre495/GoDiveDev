import AuthenticationServices
import Foundation
import SwiftData

/// After Sign in with Apple or session restore — pull Firebase social data and iCloud dive log into the local store.
enum AccountRemoteDataPopulation: Sendable {

    enum Trigger: Sendable {
        case sessionRestore
        case signInWithApple
    }

    struct SignInWithAppleRequest: Sendable {
        let identityToken: Data?
        let rawNonce: String?
        let fullName: PersonNameComponents?
        let displayName: String
        let appleUserIdentifier: String
        let interests: [String]
        let profileID: UUID
        let deferFirestoreProfileDocumentWrite: Bool
    }

    /// Runs Firebase + CloudKit merge work for the signed-in profile. When private iCloud mirroring was
    /// off, requests a one-shot store reconnect (handled by **`ProductionAppRoot`**) then returns — the
    /// reload path calls this again with **`skipCloudKitReconnect: true`**.
    @MainActor
    static func populateSignedInAccount(
        trigger: Trigger,
        modelContext: ModelContext,
        signInWithApple: SignInWithAppleRequest? = nil,
        skipCloudKitReconnect: Bool = false,
        treatAsNewAccount: Bool = false,
        mergedDuplicateCount: Int = 0,
        holdsLaunchOverlay: Bool = true
    ) async {
        guard AccountSession.shared.currentProfile != nil
            || signInWithApple != nil
            || trigger == .sessionRestore
        else { return }

        if holdsLaunchOverlay {
            AccountSession.shared.beginRemoteAccountPopulation()
        }
        defer {
            if holdsLaunchOverlay {
                AccountSession.shared.endRemoteAccountPopulation()
            }
        }

        if !skipCloudKitReconnect,
           trigger != .signInWithApple,
           shouldReconnectPrivateCloudKit(
            modelContext: modelContext,
            treatAsNewAccount: treatAsNewAccount,
            mergedDuplicateCount: mergedDuplicateCount,
            signInWithApple: signInWithApple
           )
        {
            AppSwiftDataDualStoreFactory.scheduleReconnectPrivateCloudKitOnNextLaunch()
            await AccountSession.shared.requestModelContainerCloudKitReconnect()
            let freshContext = AccountSession.shared.activeModelContainer?.mainContext ?? modelContext
            await populateSignedInAccount(
                trigger: trigger,
                modelContext: freshContext,
                signInWithApple: signInWithApple,
                skipCloudKitReconnect: true,
                treatAsNewAccount: treatAsNewAccount,
                mergedDuplicateCount: mergedDuplicateCount,
                holdsLaunchOverlay: holdsLaunchOverlay
            )
            return
        }

        let profile: UserProfile?
        if let session = AccountSession.shared.currentProfile {
            profile = session
        } else if let signInWithApple {
            let ctx = AccountSession.shared.activeModelContainer?.mainContext ?? modelContext
            profile = try? UserProfileStore.profile(id: signInWithApple.profileID, modelContext: ctx)
        } else if trigger == .sessionRestore {
            let ctx = AccountSession.shared.activeModelContainer?.mainContext ?? modelContext
            let appleID = GoDiveKeychainStore.string(for: .lastAppleUserIdentifier)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let preferredID = AppLaunchSessionRestorePresentation.loadPersistedProfileID()
                ?? ReturningAccountHints.rememberedProfileID(forAppleUserIdentifier: appleID)
            if let preferredID, !appleID.isEmpty {
                profile = await AccountSessionProfileResolution.resolve(
                    preferredProfileID: preferredID,
                    appleUserIdentifier: appleID,
                    modelContext: ctx,
                    waitForCloudKitImport: true,
                    importTimeoutSeconds: holdsLaunchOverlay
                        ? AccountSessionProfileResolution.launchImportTimeoutSeconds
                        : AccountSessionProfileResolution.defaultImportTimeoutSeconds
                )
            } else {
                profile = nil
            }
        } else {
            profile = AccountSession.shared.currentProfile
        }
        guard let profile else { return }

        let liveContext = AccountSession.shared.activeModelContainer?.mainContext ?? modelContext
        guard let liveProfile = try? UserProfileStore.profile(id: profile.id, modelContext: liveContext) else {
            return
        }

        if trigger == .signInWithApple, let signInWithApple {
            await runFirebaseSignInPhase(signInWithApple, profile: liveProfile, modelContext: liveContext)
        } else {
            await runFirebaseSessionPhase(profile: liveProfile, modelContext: liveContext)
        }

        await runCloudKitAndLocalPhase(profile: liveProfile, modelContext: liveContext, trigger: trigger)
    }

    @MainActor
    static func shouldReconnectBeforeSignIn(
        appleUserIdentifier: String,
        modelContext: ModelContext,
        defaults: UserDefaults = .standard
    ) -> Bool {
        _ = appleUserIdentifier
        return shouldReconnectPrivateCloudKit(
            modelContext: modelContext,
            treatAsNewAccount: false,
            mergedDuplicateCount: 0,
            signInWithApple: nil,
            defaults: defaults
        )
    }

    /// Sticky local-only + empty on-device log — reopen private CloudKit so iCloud dives can import.
    @MainActor
    private static func shouldReconnectPrivateCloudKit(
        modelContext: ModelContext,
        treatAsNewAccount: Bool,
        mergedDuplicateCount: Int,
        signInWithApple: SignInWithAppleRequest?,
        defaults: UserDefaults = .standard
    ) -> Bool {
        _ = treatAsNewAccount
        _ = mergedDuplicateCount
        _ = signInWithApple
        guard GoDiveCloudKitDiveLogLocalStatus.readPrivateSyncState(defaults: defaults) == .disabled else {
            return false
        }
        let dives = (try? modelContext.fetchCount(FetchDescriptor<DiveActivity>())) ?? 0
        let snorkels = (try? modelContext.fetchCount(FetchDescriptor<SnorkelActivity>())) ?? 0
        return dives + snorkels == 0
    }

    @MainActor
    private static func runFirebaseSignInPhase(
        _ request: SignInWithAppleRequest,
        profile: UserProfile,
        modelContext: ModelContext
    ) async {
        let outcome = await GoDiveFirestoreUserProfileSync.syncAfterAppleSignIn(
            identityToken: request.identityToken,
            rawNonce: request.rawNonce,
            fullName: request.fullName,
            displayName: request.displayName,
            appleUserIdentifier: request.appleUserIdentifier,
            interests: request.interests,
            deferProfileDocumentWrite: request.deferFirestoreProfileDocumentWrite
        )
        if case let .upserted(_, remoteDisplayName) = outcome {
            AccountSession.shared.applyRemoteDisplayNameIfNeeded(
                profileID: request.profileID,
                remoteDisplayName: remoteDisplayName,
                modelContext: modelContext
            )
        }
        _ = await GoDiveFirestoreProfilePhotoRestore.restoreIntoLocalProfileIfNeeded(
            profile: profile,
            modelContext: modelContext
        )
    }

    @MainActor
    private static func runFirebaseSessionPhase(profile: UserProfile, modelContext: ModelContext) async {
        let interests = GoDiveFirestoreUserProfileMapping.interests(
            doesScubaDiving: profile.doesScubaDiving,
            doesFreeDiving: profile.doesFreeDiving,
            doesSnorkeling: profile.doesSnorkeling
        )
        let sessionProfileID = profile.id
        let diveCount = (try? modelContext.fetchCount(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate { $0.ownerProfileID == sessionProfileID }
            )
        )) ?? 0
        if case let .upserted(_, remoteDisplayName) = await GoDiveFirestoreUserProfileSync.syncIfAuthenticated(
            displayName: profile.displayName,
            appleUserIdentifier: profile.appleUserIdentifier,
            interests: interests,
            totalDiveCount: diveCount
        ) {
            AccountSession.shared.applyRemoteDisplayNameIfNeeded(
                profileID: profile.id,
                remoteDisplayName: remoteDisplayName,
                modelContext: modelContext
            )
        }
        _ = await GoDiveFirestoreProfilePhotoRestore.restoreIntoLocalProfileIfNeeded(
            profile: profile,
            modelContext: modelContext
        )
        await GoDiveFriendBuddyLinking.syncRosterLinksIfPossible(
            owner: profile,
            modelContext: modelContext
        )
    }

    @MainActor
    private static func runCloudKitAndLocalPhase(
        profile: UserProfile,
        modelContext: ModelContext,
        trigger: Trigger
    ) async {
        _ = try? AccountSession.shared.reconcileCloudKitIdentityIfNeeded(modelContext: modelContext)

        await AppLaunchSessionValidation.validatePersistedSessionIfNeeded(
            profileID: profile.id,
            appleUserIdentifier: profile.appleUserIdentifier,
            container: modelContext.container
        )

        if trigger == .signInWithApple {
            await GoDiveFriendBuddyLinking.syncRosterLinksIfPossible(
                owner: profile,
                modelContext: modelContext
            )
        }

        let ownedProfileID = profile.id
        let ownedDives = (try? modelContext.fetchCount(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate { $0.ownerProfileID == ownedProfileID }
            )
        )) ?? 0
        let ownedSnorkels = (try? modelContext.fetchCount(
            FetchDescriptor<SnorkelActivity>(
                predicate: #Predicate { $0.ownerProfileID == ownedProfileID }
            )
        )) ?? 0
        if ownedDives + ownedSnorkels == 0 || trigger == .signInWithApple {
            AccountSessionCloudKitIdentityObserver.schedulePostSignInReconcileRetries(
                container: modelContext.container
            )
        }
    }
}
