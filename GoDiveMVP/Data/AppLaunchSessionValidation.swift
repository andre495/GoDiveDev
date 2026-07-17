import AuthenticationServices
import Foundation
import SwiftData

/// Deferred Sign in with Apple validation + ownership claims — runs after the launch overlay dismisses.
enum AppLaunchSessionValidation: Sendable {

    /// Validates Apple ID state and claims pre-account dives/buddies off the main actor.
    @MainActor
    static func validatePersistedSessionIfNeeded(
        profileID: UUID,
        appleUserIdentifier: String,
        container: ModelContainer
    ) async {
        let signpostID = AppPerformanceSignpost.begin(.launchSessionValidation)
        defer { AppPerformanceSignpost.end(.launchSessionValidation, signpostID: signpostID) }

        guard AccountSession.shared.currentProfile?.id == profileID else { return }

        let credentialState: ASAuthorizationAppleIDProvider.CredentialState?
        let checkFailed: Bool
        do {
            credentialState = try await ASAuthorizationAppleIDProvider().credentialState(
                forUserID: appleUserIdentifier
            )
            checkFailed = false
        } catch {
            credentialState = nil
            checkFailed = true
        }

        if AppLaunchSessionValidationPolicy.shouldSignOut(
            credentialState: credentialState,
            checkFailed: checkFailed
        ) {
            AccountSession.shared.signOut()
            return
        }

        await performOwnershipClaims(profileID: profileID, container: container)
    }

    private static func performOwnershipClaims(
        profileID: UUID,
        container: ModelContainer
    ) async {
        await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            context.autosaveEnabled = true
            guard let profile = try? UserProfileStore.profile(id: profileID, modelContext: context) else {
                return
            }
            let outcome = try? UserProfileCloudKitIdentityMerge.reconcile(
                appleUserIdentifier: profile.appleUserIdentifier,
                preferredSessionProfileID: profile.id,
                modelContext: context
            )
            let canonicalID = outcome?.canonicalProfileID ?? profileID
            guard let canonical = try? UserProfileStore.profile(id: canonicalID, modelContext: context) else {
                return
            }
            try? UserProfileStore.applyDisplayNameFromApple(
                to: canonical,
                appleProvided: nil,
                appleUserIdentifier: canonical.appleUserIdentifier,
                modelContext: context
            )
            try? DiveActivityOwnership.claimUnownedDives(for: canonical, modelContext: context)
            try? DiveBuddyOwnership.claimUnownedBuddies(for: canonical, modelContext: context)
            try? UserPreferencesSync.syncForSignedInOwner(canonical, modelContext: context)
            if canonical.id != profileID {
                await MainActor.run {
                    _ = try? AccountSession.shared.reconcileCloudKitIdentityIfNeeded(
                        modelContext: container.mainContext
                    )
                }
            }
        }.value
    }
}

/// Offline-first session policy for deferred Apple credential checks.
enum AppLaunchSessionValidationPolicy: Sendable {
    nonisolated static func shouldSignOut(
        credentialState: ASAuthorizationAppleIDProvider.CredentialState?,
        checkFailed: Bool
    ) -> Bool {
        if checkFailed { return false }
        guard let credentialState else { return false }
        switch credentialState {
        case .authorized:
            return false
        default:
            return true
        }
    }
}
