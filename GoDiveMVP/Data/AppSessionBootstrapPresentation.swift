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
        // Keep splash until Home first paint is ready — never reveal an empty dashboard.
        if showsMainAppShell && !isHomeLaunchChromeReady { return true }
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
