import Foundation

/// When the signed-in bootstrap overlay stays up through session restore and first Home paint.
enum AppSessionBootstrapPresentation: Sendable {

    /// **`true`** while restoring, loading account data, or waiting for Home stats + carousel seed.
    nonisolated static func showsLaunchOverlay(
        isRestoringSession: Bool,
        isPopulatingRemoteAccountData: Bool,
        showsMainAppShell: Bool = false,
        isHomeLaunchChromeReady: Bool = false
    ) -> Bool {
        if isRestoringSession || isPopulatingRemoteAccountData { return true }
        if showsMainAppShell && !isHomeLaunchChromeReady { return true }
        return false
    }

    /// **`true`** while sync is in progress (gates not released) for returning accounts.
    nonisolated static func showsAccountSyncOverlay(
        syncStatus: AccountSyncState.Status
    ) -> Bool {
        switch syncStatus {
        case .syncing:
            true
        case .failed:
            true
        case .idle, .ready, .timedOut:
            false
        }
    }

    /// **`true`** when sync timed out but gates are still pending (show banner on Home).
    nonisolated static func showsSyncBanner(
        syncStatus: AccountSyncState.Status
    ) -> Bool {
        if case .timedOut = syncStatus { return true }
        return false
    }

    /// Once **`ContentView`** is mounted under the splash, pass touches through (including the opacity fade).
    /// Blocking hits while fading would leave Home looking ready but dead for ~200ms.
    nonisolated static func launchOverlayAllowsHitTesting(
        showsMainAppShell: Bool,
        isHomeLaunchChromeReady: Bool = false
    ) -> Bool {
        _ = isHomeLaunchChromeReady
        return !showsMainAppShell
    }
}
