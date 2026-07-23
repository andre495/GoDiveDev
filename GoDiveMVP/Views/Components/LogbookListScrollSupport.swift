import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Notification.Name {
    /// Posted when the user taps the already-selected **Logbook** tab.
    static let logbookTabReselected = Notification.Name("GoDive.logbookTabReselected")
    /// Posted when the user taps the already-selected **Field Guide** tab.
    static let fieldGuideTabReselected = Notification.Name("GoDive.fieldGuideTabReselected")
    /// Posted when the user taps the already-selected **Explore** tab.
    static let exploreTabReselected = Notification.Name("GoDive.exploreTabReselected")
}

#if canImport(UIKit)

/// Forwards **`UITabBarControllerDelegate`** so iOS 18+ built-in re-tap scroll/pop still runs, while posting tab-specific notifications for custom list scroll fallbacks.
private final class RootTabBarReselectForwarder: NSObject, UITabBarControllerDelegate {
    static let shared = RootTabBarReselectForwarder()

    private weak var tabBarController: UITabBarController?
    private weak var forwardedDelegate: UITabBarControllerDelegate?
    private var tabIndexNotifications: [Int: Notification.Name] = [:]

    func registerReselectNotification(_ notification: Notification.Name, from view: UIView) {
        guard let viewController = view.nearestViewController,
              let tabBarController = viewController.tabBarController,
              let tabRoots = tabBarController.viewControllers
        else { return }

        guard let index = tabRoots.firstIndex(where: { isMember(viewController, ofTabRoot: $0) }) else { return }

        if self.tabBarController !== tabBarController {
            self.tabBarController = tabBarController
            if tabBarController.delegate !== self {
                if let existing = tabBarController.delegate, existing !== self {
                    forwardedDelegate = existing
                }
                tabBarController.delegate = self
            }
        }

        tabIndexNotifications[index] = notification
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if tabBarController.selectedViewController === viewController,
           let index = tabBarController.viewControllers?.firstIndex(of: viewController),
           let notification = tabIndexNotifications[index] {
            NotificationCenter.default.post(name: notification, object: nil)
        }

        if let forwardedDelegate,
           forwardedDelegate.responds(to: #selector(UITabBarControllerDelegate.tabBarController(_:shouldSelect:))) {
            return forwardedDelegate.tabBarController!(tabBarController, shouldSelect: viewController)
        }
        return true
    }

    private func isMember(_ member: UIViewController, ofTabRoot root: UIViewController) -> Bool {
        if member === root { return true }
        if let navigationController = root as? UINavigationController {
            if navigationController.viewControllers.contains(where: { $0 === member }) { return true }
            if member.navigationController === navigationController { return true }
        }
        var current: UIViewController? = member
        while let viewController = current {
            if viewController === root { return true }
            current = viewController.parent
        }
        return false
    }
}

private extension UIResponder {
    var nearestViewController: UIViewController? {
        sequence(first: self, next: \.next)
            .compactMap { $0 as? UIViewController }
            .first
    }
}

private struct RootTabBarReselectInstaller: UIViewRepresentable {
    let notification: Notification.Name

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            RootTabBarReselectForwarder.shared.registerReselectNotification(notification, from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            RootTabBarReselectForwarder.shared.registerReselectNotification(notification, from: uiView)
        }
    }
}

/// Scrolls the nearest SwiftUI **`List`** scroll view when **`nonce`** changes.
struct ListScrollToTopTrigger: UIViewRepresentable {
    let nonce: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        Self.enableScrollsToTop(from: uiView)
        guard nonce > 0, context.coordinator.lastNonce != nonce else { return }
        context.coordinator.lastNonce = nonce
        DispatchQueue.main.async {
            Self.scrollToTop(from: uiView)
        }
    }

    final class Coordinator {
        var lastNonce = 0
    }

    private static func enableScrollsToTop(from view: UIView) {
        if let scrollView = findScrollView(startingFrom: view) {
            scrollView.scrollsToTop = true
        }
    }

    private static func scrollToTop(from view: UIView) {
        guard let scrollView = findScrollView(startingFrom: view) else { return }
        scrollView.scrollsToTop = true
        let topOffset = CGPoint(x: 0, y: -scrollView.adjustedContentInset.top)
        scrollView.setContentOffset(topOffset, animated: true)

        if let tableView = scrollView as? UITableView,
           tableView.numberOfSections > 0,
           tableView.numberOfRows(inSection: 0) > 0 {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
    }

    private static func findScrollView(startingFrom view: UIView) -> UIScrollView? {
        var current: UIView? = view
        while let candidate = current {
            if let scrollView = candidate as? UIScrollView {
                return scrollView
            }
            if let scrollView = findScrollView(in: candidate) {
                return scrollView
            }
            current = candidate.superview
        }
        return nil
    }

    private static func findScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let scrollView = findScrollView(in: subview) {
                return scrollView
            }
        }
        return nil
    }
}

enum RootTabListScrollSupport {
    /// Yields one run loop turn before **`bumpScrollToTopNonce`** so UIKit can attach the list scroll view.
    @MainActor
    static func scheduleScrollToTop(bumpScrollToTopNonce: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(32))
            bumpScrollToTopNonce()
        }
    }
}
#endif

extension View {
    /// Observes re-taps on the active tab without replacing the tab bar's scroll-to-top behavior.
    func rootTabReselectObserver(notification: Notification.Name) -> some View {
        #if canImport(UIKit)
        background {
            RootTabBarReselectInstaller(notification: notification)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        #else
        self
        #endif
    }

    /// Scrolls the enclosing **`List`** to the top when **`nonce`** changes (tab re-tap fallback).
    func listScrollToTopTrigger(nonce: Int) -> some View {
        #if canImport(UIKit)
        overlay(alignment: .top) {
            ListScrollToTopTrigger(nonce: nonce)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        #else
        self
        #endif
    }

    func logbookTabReselectObserver() -> some View {
        rootTabReselectObserver(notification: .logbookTabReselected)
    }

    func logbookListScrollToTopTrigger(nonce: Int) -> some View {
        listScrollToTopTrigger(nonce: nonce)
    }

    /// Pull-to-refresh on Activity Log **Buddy Feed** (list, empty, and initial loading scroll surfaces).
    func logbookBuddyFeedPullToRefresh(action: @escaping () async -> Void) -> some View {
        refreshable {
            await action()
        }
    }
}
