import Foundation
import UIKit

/// Declarative rules for which navigation destinations stay portrait (tests / docs).
enum AppPortraitOrientationLockPolicy: Sendable {

    /// Portrait everywhere except **`ViewSingleActivity`** (landscape tank profile).
    nonisolated static func locksUnlessShowingDiveActivity(_ isShowingDiveActivity: Bool) -> Bool {
        !isShowingDiveActivity
    }

    nonisolated static func homeRouteIsDiveActivity(_ route: HomeRoute) -> Bool {
        switch route {
        case .diveDetail, .diveMedia:
            return true
        case .profile, .tripPlanner, .tripDetail, .tripDetailMedia, .diveSite, .marineLife, .diveBuddy,
             .lifetimeStatsLeaderboard:
            return false
        }
    }

    nonisolated static func logbookRouteIsDiveActivity(_ route: LogbookRoute) -> Bool {
        switch route {
        case .diveDetail, .diveMedia:
            return true
        case .addActivity, .tripPlanner, .tripDetail, .tripDetailMedia, .diveSite:
            return false
        }
    }

    nonisolated static func exploreRouteIsDiveActivity(_ route: ExploreRoute) -> Bool {
        if case .diveDetail = route { return true }
        return false
    }

    nonisolated static func locksHome(path: [HomeRoute]) -> Bool {
        guard let top = path.last else { return true }
        return !homeRouteIsDiveActivity(top)
    }

    nonisolated static func locksLogbook(path: [LogbookRoute]) -> Bool {
        guard let top = path.last else { return true }
        return !logbookRouteIsDiveActivity(top)
    }

    nonisolated static func locksFieldGuide(isShowingDiveDetail: Bool) -> Bool {
        !isShowingDiveDetail
    }

    nonisolated static func locksExplore(path: [ExploreRoute]) -> Bool {
        guard let top = path.last else { return true }
        return !exploreRouteIsDiveActivity(top)
    }

    nonisolated static func locksTripDetail(showingLinkedDiveDetail: Bool) -> Bool {
        !showingLinkedDiveDetail
    }

    /// Runtime mask from active **`ViewSingleActivity`** landscape unlock depth.
    nonisolated static func supportedInterfaceOrientations(landscapeUnlockCount: Int) -> UIInterfaceOrientationMask {
        landscapeUnlockCount > 0
            ? [.portrait, .landscapeLeft, .landscapeRight]
            : .portrait
    }
}

/// Global orientation policy consulted by **`GoDiveGoogleMapsAppDelegate`**.
///
/// **Default:** portrait only. **`ViewSingleActivity`** calls **`acquireLandscapeUnlock()`** while visible.
@MainActor
final class AppPortraitOrientationLockController {
    static let shared = AppPortraitOrientationLockController()

    private(set) var landscapeUnlockCount = 0

    var supportedMask: UIInterfaceOrientationMask {
        AppPortraitOrientationLockPolicy.supportedInterfaceOrientations(
            landscapeUnlockCount: landscapeUnlockCount
        )
    }

    private init() {}

    func acquireLandscapeUnlock() {
        landscapeUnlockCount += 1
        applyRotationPolicy()
    }

    func releaseLandscapeUnlock() {
        landscapeUnlockCount = max(0, landscapeUnlockCount - 1)
        applyRotationPolicy()
    }

    private func applyRotationPolicy() {
        let mask = supportedMask
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        if let activeScene {
            activeScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        }
        for scene in scenes {
            scene.windows.forEach { window in
                var controller = window.rootViewController
                while let current = controller {
                    current.setNeedsUpdateOfSupportedInterfaceOrientations()
                    controller = current.presentedViewController
                }
            }
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI

extension View {
    /// Landscape allowed only while **`ViewSingleActivity`** (map / tank / media tabs) is visible.
    func diveActivityLandscapeOrientation() -> some View {
        modifier(DiveActivityLandscapeOrientationModifier())
    }
}

private struct DiveActivityLandscapeOrientationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                AppPortraitOrientationLockController.shared.acquireLandscapeUnlock()
            }
            .onDisappear {
                AppPortraitOrientationLockController.shared.releaseLandscapeUnlock()
            }
    }
}
#endif
