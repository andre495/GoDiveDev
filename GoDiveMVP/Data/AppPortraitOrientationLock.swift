import Foundation
import UIKit

/// Screens that should stay portrait-only while visible (lists / catalog browse).
enum AppPortraitOrientationLockPolicy: Sendable {

    nonisolated static func locksHome(pathIsEmpty: Bool) -> Bool {
        pathIsEmpty
    }

    nonisolated static func locksLogbook(pathIsEmpty: Bool) -> Bool {
        pathIsEmpty
    }

    /// **Field Guide** root, category, subcategory, and species detail — not dive activity.
    nonisolated static func locksFieldGuide(isShowingDiveDetail: Bool) -> Bool {
        !isShowingDiveDetail
    }

    /// **Explore** dive-site list root only (not map mode or pushed destinations).
    nonisolated static func locksExploreList(pathIsEmpty: Bool, viewModeIsList: Bool) -> Bool {
        pathIsEmpty && viewModeIsList
    }
}

/// Global portrait lock consulted by **`GoDiveGoogleMapsAppDelegate`** and rotation requests.
@MainActor
final class AppPortraitOrientationLockController {
    static let shared = AppPortraitOrientationLockController()

    private(set) var isPortraitLocked = false

    var supportedMask: UIInterfaceOrientationMask {
        isPortraitLocked ? .portrait : [.portrait, .landscapeLeft, .landscapeRight]
    }

    private init() {}

    func updatePortraitLock(_ locked: Bool) {
        guard isPortraitLocked != locked else { return }
        isPortraitLocked = locked
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
            scene.windows.forEach { root in
                root.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI

extension View {
    /// Keeps the app in portrait while **`isLocked`** is **`true`** (releases on disappear).
    func portraitOrientationLock(when isLocked: Bool) -> some View {
        modifier(PortraitOrientationLockWhenModifier(isLocked: isLocked))
    }
}

private struct PortraitOrientationLockWhenModifier: ViewModifier {
    let isLocked: Bool

    func body(content: Content) -> some View {
        content
            .background {
                PortraitOrientationLockHost()
            }
            .onAppear {
                AppPortraitOrientationLockController.shared.updatePortraitLock(isLocked)
            }
            .onChange(of: isLocked) { _, locked in
                AppPortraitOrientationLockController.shared.updatePortraitLock(locked)
            }
            .onDisappear {
                AppPortraitOrientationLockController.shared.updatePortraitLock(false)
            }
    }
}

/// Ensures the hosting controller participates in orientation updates.
private struct PortraitOrientationLockHost: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PortraitOrientationLockViewController {
        PortraitOrientationLockViewController()
    }

    func updateUIViewController(_ uiViewController: PortraitOrientationLockViewController, context: Context) {}
}

private final class PortraitOrientationLockViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppPortraitOrientationLockController.shared.supportedMask
    }
}
#endif
