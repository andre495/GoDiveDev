import Foundation

/// When root tabs may drain pending push / reminder navigation stores into routes.
///
/// Cold start often delivers the notification tap **before** `ContentView` exists, so
/// `NotificationCenter` posts are lost. Pending targets must be flushed when the shell
/// is ready — including **`ContentView.onAppear`**, because `onChange(of: showsMainAppShell)`
/// does not fire when the shell is already visible on first mount.
enum GoDiveRootPushDeepLinkFlushPresentation: Sendable {
    /// Require main shell **and** Home launch chrome so splash/restore cannot consume
    /// a pending target and then remount tabs with an empty stack.
    nonisolated static func canOpenPendingRoutes(
        showsMainAppShell: Bool,
        isHomeLaunchChromeReady: Bool
    ) -> Bool {
        showsMainAppShell && isHomeLaunchChromeReady
    }
}
