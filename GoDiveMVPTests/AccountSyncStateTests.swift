//
//  AccountSyncStateTests.swift
//  GoDiveMVPTests
//

import Foundation
import Testing
@testable import GoDiveMVP

struct AccountSyncStateTests {

    // MARK: - State Transitions

    @Test @MainActor
    func syncState_beginSync_transitionsToSyncing() {
        let state = AccountSyncState()
        #expect(state.status == .idle)

        state.beginSync(gates: [.firebaseAuth, .cloudKitImport])

        #expect(state.status == .syncing)
        #expect(state.pendingGates.contains(.firebaseAuth))
        #expect(state.pendingGates.contains(.cloudKitImport))
        #expect(state.isSyncing)
        #expect(!state.isReady)
    }

    @Test @MainActor
    func syncState_releaseGate_removesFromPending() {
        let state = AccountSyncState()
        state.beginSync(gates: [.firebaseAuth, .firestoreProfile])

        state.releaseGate(.firebaseAuth)

        #expect(!state.pendingGates.contains(.firebaseAuth))
        #expect(state.completedGates.contains(.firebaseAuth))
        #expect(state.pendingGates.contains(.firestoreProfile))
        #expect(state.isSyncing)
    }

    @Test @MainActor
    func syncState_releaseAllGates_transitionsToReady() {
        let state = AccountSyncState()
        state.beginSync(gates: [.firebaseAuth, .cloudKitImport, .firestoreProfile])

        state.releaseGate(.firebaseAuth)
        state.releaseGate(.cloudKitImport)
        state.releaseGate(.firestoreProfile)

        #expect(state.status == .ready)
        #expect(state.isReady)
        #expect(!state.isSyncing)
        #expect(state.pendingGates.isEmpty)
    }

    @Test @MainActor
    func syncState_timeout_transitionsToTimedOut() {
        let state = AccountSyncState()
        state.beginSync(gates: [.cloudKitImport])

        state.timeout()

        #expect(state.status == .timedOut)
        #expect(state.hasTimedOut)
        #expect(!state.isSyncing)
    }

    @Test @MainActor
    func syncState_fail_transitionsToFailed() {
        let state = AccountSyncState()
        state.beginSync(gates: [.firebaseAuth])

        state.fail(.offline)

        #expect(state.status == .failed(.offline))
        #expect(state.hasFailed)
        #expect(state.failureReason == .offline)
    }

    @Test @MainActor
    func syncState_reset_clearsAllState() {
        let state = AccountSyncState()
        state.beginSync(gates: [.firebaseAuth, .cloudKitImport])
        state.releaseGate(.firebaseAuth)

        state.reset()

        #expect(state.status == .idle)
        #expect(state.pendingGates.isEmpty)
        #expect(state.completedGates.isEmpty)
    }

    @Test @MainActor
    func syncState_completeAfterTimeout_transitionsToReady() {
        let state = AccountSyncState()
        state.beginSync(gates: [.cloudKitImport])
        state.timeout()

        state.completeAfterTimeout()

        #expect(state.status == .ready)
        #expect(state.isReady)
    }

    @Test @MainActor
    func syncState_prepareForRetry_resetsToIdle() {
        let state = AccountSyncState()
        state.beginSync(gates: [.firebaseAuth])
        state.fail(.offline)

        state.prepareForRetry()

        #expect(state.status == .idle)
    }

    // MARK: - Gate Release Behavior

    @Test @MainActor
    func syncState_releaseGate_ignoresNonPendingGates() {
        let state = AccountSyncState()
        state.beginSync(gates: [.firebaseAuth])

        state.releaseGate(.cloudKitImport)

        #expect(state.pendingGates.count == 1)
        #expect(state.completedGates.isEmpty)
    }

    @Test @MainActor
    func syncState_releaseAllGates_immediateTransitionsToReady() {
        let state = AccountSyncState()
        state.beginSync(gates: [.firebaseAuth, .cloudKitImport, .firestoreProfile, .socialFirstSnapshot])

        state.releaseAllGates()

        #expect(state.status == .ready)
        #expect(state.pendingGates.isEmpty)
        #expect(state.completedGates.count == 4)
    }

    // MARK: - Progress Messages

    @Test
    func syncLoadingPresentation_progressMessage_prioritizesCloudKit() {
        let message = AccountSyncLoadingPresentation.progressMessage(for: [.cloudKitImport, .firebaseAuth])
        #expect(message == "Restoring your dives…")
    }

    @Test
    func syncLoadingPresentation_progressMessage_showsAccountForFirebase() {
        let message = AccountSyncLoadingPresentation.progressMessage(for: [.firebaseAuth])
        #expect(message == "Loading account…")
    }

    @Test
    func syncLoadingPresentation_progressMessage_showsFriendsForSocialSnapshot() {
        let message = AccountSyncLoadingPresentation.progressMessage(for: [.socialFirstSnapshot])
        #expect(message == "Loading friends…")
    }

    @Test
    func syncLoadingPresentation_progressMessage_fallsBackToLoading() {
        let message = AccountSyncLoadingPresentation.progressMessage(for: [])
        #expect(message == "Loading…")
    }

    // MARK: - Gate Determination

    @Test
    func syncState_gatesForReturningAccount_includesAllWhenConfigured() {
        let gates = AccountSyncState.gatesForReturningAccount(
            hasFirebaseConfig: true,
            isICloudAvailable: true
        )

        #expect(gates.contains(.firebaseAuth))
        #expect(gates.contains(.firestoreProfile))
        #expect(gates.contains(.cloudKitImport))
        #expect(gates.contains(.socialFirstSnapshot))
    }

    @Test
    func syncState_gatesForReturningAccount_excludesFirebaseWhenNotConfigured() {
        let gates = AccountSyncState.gatesForReturningAccount(
            hasFirebaseConfig: false,
            isICloudAvailable: true
        )

        #expect(!gates.contains(.firebaseAuth))
        #expect(!gates.contains(.firestoreProfile))
        #expect(!gates.contains(.socialFirstSnapshot))
        #expect(gates.contains(.cloudKitImport))
    }

    @Test
    func syncState_gatesForReturningAccount_excludesCloudKitWhenUnavailable() {
        let gates = AccountSyncState.gatesForReturningAccount(
            hasFirebaseConfig: true,
            isICloudAvailable: false
        )

        #expect(!gates.contains(.cloudKitImport))
        #expect(gates.contains(.firebaseAuth))
    }

    @Test
    func syncState_shouldShowSyncScreen_falseForNewAccount() {
        #expect(!AccountSyncState.shouldShowSyncScreen(
            treatAsNewAccount: true,
            hasReturningHints: true
        ))
    }

    @Test
    func syncState_shouldShowSyncScreen_falseWithoutReturningHints() {
        #expect(!AccountSyncState.shouldShowSyncScreen(
            treatAsNewAccount: false,
            hasReturningHints: false
        ))
    }

    @Test
    func syncState_shouldShowSyncScreen_trueForReturningAccount() {
        #expect(AccountSyncState.shouldShowSyncScreen(
            treatAsNewAccount: false,
            hasReturningHints: true
        ))
    }

    // MARK: - Failure Reasons

    @Test
    func failureReason_description_returnsExpectedStrings() {
        #expect(AccountSyncState.FailureReason.offline.description == "Network unavailable")
        #expect(AccountSyncState.FailureReason.iCloudUnavailable.description == "iCloud unavailable")
        #expect(AccountSyncState.FailureReason.unknown("Custom").description == "Custom")
    }

    // MARK: - Bootstrap Presentation

    @Test
    func appSessionBootstrapPresentation_showsAccountSyncOverlay_trueWhileSyncing() {
        #expect(AppSessionBootstrapPresentation.showsAccountSyncOverlay(syncStatus: .syncing))
    }

    @Test
    func appSessionBootstrapPresentation_showsAccountSyncOverlay_trueWhenFailed() {
        #expect(AppSessionBootstrapPresentation.showsAccountSyncOverlay(syncStatus: .failed(.offline)))
    }

    @Test
    func appSessionBootstrapPresentation_showsAccountSyncOverlay_falseWhenReady() {
        #expect(!AppSessionBootstrapPresentation.showsAccountSyncOverlay(syncStatus: .ready))
    }

    @Test
    func appSessionBootstrapPresentation_showsAccountSyncOverlay_falseWhenTimedOut() {
        #expect(!AppSessionBootstrapPresentation.showsAccountSyncOverlay(syncStatus: .timedOut))
    }

    @Test
    func appSessionBootstrapPresentation_showsSyncBanner_trueWhenTimedOut() {
        #expect(AppSessionBootstrapPresentation.showsSyncBanner(syncStatus: .timedOut))
    }

    @Test
    func appSessionBootstrapPresentation_showsSyncBanner_falseWhenSyncing() {
        #expect(!AppSessionBootstrapPresentation.showsSyncBanner(syncStatus: .syncing))
    }

    // MARK: - Presentation Copy

    @Test
    func syncLoadingPresentation_copyTokens_areNonEmpty() {
        #expect(!AccountSyncLoadingPresentation.offlineTitle.isEmpty)
        #expect(!AccountSyncLoadingPresentation.offlineMessage.isEmpty)
        #expect(!AccountSyncLoadingPresentation.iCloudUnavailableTitle.isEmpty)
        #expect(!AccountSyncLoadingPresentation.iCloudUnavailableMessage.isEmpty)
        #expect(!AccountSyncLoadingPresentation.retryButtonTitle.isEmpty)
        #expect(!AccountSyncLoadingPresentation.continueButtonTitle.isEmpty)
        #expect(!AccountSyncLoadingPresentation.stillSyncingBannerMessage.isEmpty)
        #expect(!AccountSyncLoadingPresentation.syncCompleteBannerMessage.isEmpty)
    }

    @Test
    func syncLoadingPresentation_timeout_isReasonable() {
        #expect(AccountSyncLoadingPresentation.timeoutSeconds == 20)
        #expect(AccountSyncLoadingPresentation.socialSnapshotDelayMilliseconds > 0)
        #expect(AccountSyncLoadingPresentation.socialSnapshotDelayMilliseconds <= 3000)
    }
}
