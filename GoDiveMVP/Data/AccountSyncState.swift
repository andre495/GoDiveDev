import Foundation

/// Tracks the initial account data sync after Sign in with Apple for returning accounts.
/// Gates must all be released before Home shows.
@MainActor
@Observable
final class AccountSyncState {

    // MARK: - Types

    enum Status: Sendable, Equatable {
        case idle
        case syncing
        case ready
        case failed(FailureReason)
        case timedOut
    }

    enum FailureReason: Sendable, Equatable, CustomStringConvertible {
        case offline
        case iCloudUnavailable
        case unknown(String)

        var description: String {
            switch self {
            case .offline:
                "Network unavailable"
            case .iCloudUnavailable:
                "iCloud unavailable"
            case .unknown(let message):
                message
            }
        }
    }

    /// Individual gates that must be released before sync is considered ready.
    enum Gate: String, Sendable, CaseIterable {
        case firebaseAuth
        case firestoreProfile
        case cloudKitImport
        case socialFirstSnapshot
    }

    // MARK: - Properties

    private(set) var status: Status = .idle
    private(set) var pendingGates: Set<Gate> = []
    private(set) var completedGates: Set<Gate> = []
    private(set) var currentProgressMessage: String = ""

    var isSyncing: Bool {
        if case .syncing = status { return true }
        return false
    }

    var isReady: Bool {
        if case .ready = status { return true }
        return false
    }

    var hasTimedOut: Bool {
        if case .timedOut = status { return true }
        return false
    }

    var hasFailed: Bool {
        if case .failed = status { return true }
        return false
    }

    var failureReason: FailureReason? {
        if case let .failed(reason) = status { return reason }
        return nil
    }

    // MARK: - State Transitions

    /// Begins sync with the specified gates. Called when a returning account signs in.
    func beginSync(gates: Set<Gate>) {
        guard status == .idle || hasTimedOut || hasFailed else { return }
        pendingGates = gates
        completedGates = []
        status = .syncing
        updateProgressMessage()
        AppLaunchTimelineLog.event("sync.begin", "gates=\(gates.map(\.rawValue).sorted().joined(separator: ","))")
    }

    /// Releases a gate as completed. If all gates are released, transitions to ready.
    func releaseGate(_ gate: Gate) {
        guard pendingGates.contains(gate) else { return }
        pendingGates.remove(gate)
        completedGates.insert(gate)
        AppLaunchTimelineLog.event("sync.gate_released", "gate=\(gate.rawValue)")

        if pendingGates.isEmpty {
            transitionToReady()
        } else {
            updateProgressMessage()
        }
    }

    /// Releases all remaining gates and transitions to ready (e.g. new account skipping sync).
    func releaseAllGates() {
        for gate in pendingGates {
            completedGates.insert(gate)
        }
        pendingGates.removeAll()
        transitionToReady()
    }

    /// Times out sync but allows Home to show with a banner.
    func timeout() {
        guard isSyncing else { return }
        status = .timedOut
        AppLaunchTimelineLog.event("sync.timeout", "pending=\(pendingGates.map(\.rawValue).sorted().joined(separator: ","))")
    }

    /// Records a failure that blocks sync.
    func fail(_ reason: FailureReason) {
        guard isSyncing else { return }
        status = .failed(reason)
        AppLaunchTimelineLog.event("sync.failed", "reason=\(reason)")
    }

    /// Resets to idle state (e.g. after sign out or retry).
    func reset() {
        status = .idle
        pendingGates = []
        completedGates = []
        currentProgressMessage = ""
    }

    /// Marks sync complete after timeout/background completion.
    func completeAfterTimeout() {
        guard hasTimedOut else { return }
        status = .ready
        pendingGates.removeAll()
        AppLaunchTimelineLog.event("sync.complete_after_timeout")
    }

    /// Retries sync after a failure. Must call beginSync again with gates.
    func prepareForRetry() {
        guard hasFailed else { return }
        status = .idle
        pendingGates = []
        completedGates = []
        currentProgressMessage = ""
    }

    // MARK: - Private

    private func transitionToReady() {
        status = .ready
        currentProgressMessage = ""
        AppLaunchTimelineLog.event("sync.ready")
    }

    private func updateProgressMessage() {
        currentProgressMessage = AccountSyncLoadingPresentation.progressMessage(for: pendingGates)
    }
}

// MARK: - Presentation

/// Copy and progress messages for the sync loading screen.
enum AccountSyncLoadingPresentation: Sendable {
    static let timeoutSeconds: Int = 20
    static let socialSnapshotDelayMilliseconds: Int = 1500

    static func progressMessage(for pendingGates: Set<AccountSyncState.Gate>) -> String {
        if pendingGates.contains(.cloudKitImport) {
            return "Restoring your dives…"
        }
        if pendingGates.contains(.firestoreProfile) || pendingGates.contains(.firebaseAuth) {
            return "Loading account…"
        }
        if pendingGates.contains(.socialFirstSnapshot) {
            return "Loading friends…"
        }
        return "Loading…"
    }

    static let offlineTitle = "You're offline"
    static let offlineMessage = "Connect to the internet to sync your account."
    static let iCloudUnavailableTitle = "iCloud unavailable"
    static let iCloudUnavailableMessage = "Sign in to iCloud to sync your dives."
    static let retryButtonTitle = "Retry"
    static let continueButtonTitle = "Continue"

    static let stillSyncingBannerMessage = "Still syncing…"
    static let syncCompleteBannerMessage = "Sync complete"
}

// MARK: - Gate Determination

extension AccountSyncState {

    /// Determines which gates to track for a returning account sign-in.
    nonisolated static func gatesForReturningAccount(
        hasFirebaseConfig: Bool = GoDiveFirebaseBootstrap.isConfigured,
        isICloudAvailable: Bool = true
    ) -> Set<Gate> {
        var gates: Set<Gate> = []

        if hasFirebaseConfig {
            gates.insert(.firebaseAuth)
            gates.insert(.firestoreProfile)
            gates.insert(.socialFirstSnapshot)
        }

        if isICloudAvailable {
            gates.insert(.cloudKitImport)
        }

        return gates
    }

    /// Returns true if sync should be shown for this account.
    nonisolated static func shouldShowSyncScreen(
        treatAsNewAccount: Bool,
        hasReturningHints: Bool
    ) -> Bool {
        if treatAsNewAccount { return false }
        return hasReturningHints
    }
}
