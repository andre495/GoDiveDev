import AuthenticationServices
import Foundation
import os
import SwiftData

/// Deferred Sign in with Apple validation + ownership claims — runs after the launch overlay dismisses.
enum AppLaunchSessionValidation: Sendable {

    private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "LaunchSessionValidation"
    )

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

        let currentAppleID = AccountSession.shared.currentProfile?.appleUserIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let checkingAppleID = appleUserIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)

        let decision = await checkCredentialWithRetries(
            appleUserIdentifier: checkingAppleID,
            currentSessionAppleID: currentAppleID,
            maxAttempts: AppLaunchSessionValidationPolicy.maxRetryAttempts
        )

        switch decision {
        case .keepSession:
            break
        case .signOut:
            log.notice("Signing out: Apple credential revoked for current account")
            GoDiveSecurityEvent.record(
                .automaticCredentialRevoked,
                ownerProfileID: profileID
            )
            AccountSession.shared.signOut(persistSecurityEvent: false)
            return
        case .inconclusive:
            log.debug("Credential check inconclusive; keeping session")
        }

        await performOwnershipClaims(profileID: profileID, container: container)
    }

    private static func checkCredentialWithRetries(
        appleUserIdentifier: String,
        currentSessionAppleID: String,
        maxAttempts: Int
    ) async -> AppleCredentialValidationDecision {
        var attempt = 0
        var lastResult = AppleCredentialCheckResult.failed

        while attempt < maxAttempts {
            let result = await performCredentialCheck(appleUserIdentifier: appleUserIdentifier)
            lastResult = result

            let decision = AppLaunchSessionValidationPolicy.evaluate(
                checkResult: result,
                checkedAppleUserID: appleUserIdentifier,
                currentSessionAppleID: currentSessionAppleID
            )

            switch decision {
            case .keepSession, .signOut:
                return decision
            case .inconclusive:
                attempt += 1
                if attempt < maxAttempts {
                    let backoffMs = AppLaunchSessionValidationPolicy.backoffMilliseconds(attempt: attempt)
                    try? await Task.sleep(for: .milliseconds(backoffMs))
                }
            }
        }

        return AppLaunchSessionValidationPolicy.evaluate(
            checkResult: lastResult,
            checkedAppleUserID: appleUserIdentifier,
            currentSessionAppleID: currentSessionAppleID
        )
    }

    private static func performCredentialCheck(
        appleUserIdentifier: String
    ) async -> AppleCredentialCheckResult {
        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(
                forUserID: appleUserIdentifier
            )
            return .success(state)
        } catch {
            return .failed
        }
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
            _ = try? DiveActivityOwnership.claimUnownedDives(for: canonical, modelContext: context)
            _ = try? SnorkelActivityOwnership.claimUnownedSnorkels(for: canonical, modelContext: context)
            _ = try? DiveBuddyOwnership.claimUnownedBuddies(for: canonical, modelContext: context)
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

/// Result of a single Apple credential state check.
enum AppleCredentialCheckResult: Sendable, Equatable {
    case success(ASAuthorizationAppleIDProvider.CredentialState)
    case failed
}

/// Action to take after evaluating the credential state.
enum AppleCredentialValidationDecision: Sendable, Equatable {
    case keepSession
    case signOut
    case inconclusive
}

/// Pure, nonisolated session policy for Apple credential checks.
///
/// - Authorized: keep session
/// - Revoked for the current account's Apple ID: sign out
/// - Revoked for a mismatched/stale ID: keep session (wrong ID being checked)
/// - NotFound, Transferred, errors, timeouts: inconclusive (keep session, allow retry)
enum AppLaunchSessionValidationPolicy: Sendable {

    /// Maximum retry attempts for inconclusive credential checks.
    nonisolated static let maxRetryAttempts = 3

    /// Evaluates the credential check result and returns the appropriate action.
    ///
    /// - Parameters:
    ///   - checkResult: The result of the Apple credential state check.
    ///   - checkedAppleUserID: The Apple user ID that was checked.
    ///   - currentSessionAppleID: The Apple user ID of the currently signed-in account.
    /// - Returns: The action to take (keepSession, signOut, or inconclusive).
    nonisolated static func evaluate(
        checkResult: AppleCredentialCheckResult,
        checkedAppleUserID: String,
        currentSessionAppleID: String
    ) -> AppleCredentialValidationDecision {
        switch checkResult {
        case .failed:
            return .inconclusive
        case .success(let state):
            return evaluateCredentialState(
                state: state,
                checkedAppleUserID: checkedAppleUserID,
                currentSessionAppleID: currentSessionAppleID
            )
        }
    }

    private nonisolated static func evaluateCredentialState(
        state: ASAuthorizationAppleIDProvider.CredentialState,
        checkedAppleUserID: String,
        currentSessionAppleID: String
    ) -> AppleCredentialValidationDecision {
        switch state {
        case .authorized:
            return .keepSession
        case .revoked:
            let normalizedChecked = checkedAppleUserID.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedCurrent = currentSessionAppleID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedChecked.isEmpty, !normalizedCurrent.isEmpty else {
                return .inconclusive
            }
            if normalizedChecked == normalizedCurrent {
                return .signOut
            }
            return .keepSession
        case .notFound, .transferred:
            return .inconclusive
        @unknown default:
            return .inconclusive
        }
    }

    /// Calculates backoff delay in milliseconds for retry attempts.
    nonisolated static func backoffMilliseconds(attempt: Int) -> Int {
        let base = 500
        let capped = min(attempt, 4)
        return base * (1 << capped)
    }

    /// Legacy compatibility — returns true only when the session should be ended.
    /// Use `evaluate(checkResult:checkedAppleUserID:currentSessionAppleID:)` for new code.
    nonisolated static func shouldSignOut(
        credentialState: ASAuthorizationAppleIDProvider.CredentialState?,
        checkFailed: Bool
    ) -> Bool {
        if checkFailed { return false }
        guard let credentialState else { return false }
        switch credentialState {
        case .authorized:
            return false
        case .revoked:
            return true
        case .notFound, .transferred:
            return false
        @unknown default:
            return false
        }
    }
}
