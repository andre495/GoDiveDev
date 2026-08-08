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
///
/// Also posts **`rootTabBarDidSelect`** on every tab change — iOS 26 `TabView` can show a new
/// tab without updating SwiftUI `selection` / **`RootTabSelectionStore`**.
private final class RootTabBarReselectForwarder: NSObject, UITabBarControllerDelegate {
    static let shared = RootTabBarReselectForwarder()

    private weak var tabBarController: UITabBarController?
    private weak var forwardedDelegate: UITabBarControllerDelegate?
    private var tabIndexNotifications: [Int: Notification.Name] = [:]

    /// Attach as tab-bar delegate from any view in the tab hierarchy (ContentView or a tab root).
    func ensureInstalled(from view: UIView) {
        guard let viewController = view.nearestViewController,
              let tabBarController = viewController.tabBarController
        else { return }
        install(on: tabBarController)
    }

    func registerReselectNotification(_ notification: Notification.Name, from view: UIView) {
        guard let viewController = view.nearestViewController,
              let tabBarController = viewController.tabBarController,
              let tabRoots = tabBarController.viewControllers
        else { return }

        guard let index = tabRoots.firstIndex(where: { isMember(viewController, ofTabRoot: $0) }) else { return }

        install(on: tabBarController)
        tabIndexNotifications[index] = notification
    }

    private func install(on tabBarController: UITabBarController) {
        if self.tabBarController !== tabBarController {
            self.tabBarController = tabBarController
        }
        if tabBarController.delegate !== self {
            if let existing = tabBarController.delegate, existing !== self {
                forwardedDelegate = existing
            }
            tabBarController.delegate = self
        }
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

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if let index = tabBarController.viewControllers?.firstIndex(of: viewController) {
            RootTabBarSelectionSync.postDidSelect(index: index)
            #if DEBUG
            let tab = RootTabBarSelectionSync.rootTab(forTabBarIndex: index)
            print("[RootTabBar] didSelect index=\(index) tab=\(String(describing: tab))")
            #endif
        }
        if let forwardedDelegate,
           forwardedDelegate.responds(to: #selector(UITabBarControllerDelegate.tabBarController(_:didSelect:))) {
            forwardedDelegate.tabBarController!(tabBarController, didSelect: viewController)
        }
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

/// Ensures the shared tab-bar delegate is installed from **`ContentView`** (selection sync).
struct RootTabBarSelectionSyncInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            RootTabBarReselectForwarder.shared.ensureInstalled(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            RootTabBarReselectForwarder.shared.ensureInstalled(from: uiView)
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

/// Publishes the nearest vertical list/scroll view as the tab’s bottom-edge content scroll view so
/// **`tabBarMinimizeBehavior(.onScrollDown)`** still engages under nested page **`TabView`**s.
enum RootTabBarMinimizeScrollAssociator {
    @MainActor
    static func associate(from view: UIView) {
        guard let scrollView = findVerticalContentScrollView(startingFrom: view) else { return }
        guard let viewController = view.nearestViewController else { return }

        // Keep SwiftUI’s scroll-under-tab-bar layout (manual bottom spacer). System adjustment
        // after **`setContentScrollView`** otherwise pins content above the menu.
        if RootTabBarMinimizeScrollPresentation.disablesContentInsetAdjustmentForScrollUnderTabBar {
            scrollView.contentInsetAdjustmentBehavior = .never
        }

        var targets: [UIViewController] = [viewController]
        if let navigationController = viewController.navigationController {
            targets.append(navigationController)
            if let top = navigationController.topViewController, top !== viewController {
                targets.append(top)
            }
        }
        if let selected = viewController.tabBarController?.selectedViewController {
            if !targets.contains(where: { $0 === selected }) {
                targets.append(selected)
            }
            if let navigationController = selected as? UINavigationController {
                if !targets.contains(where: { $0 === navigationController }) {
                    targets.append(navigationController)
                }
                if let top = navigationController.topViewController,
                   !targets.contains(where: { $0 === top }) {
                    targets.append(top)
                }
            }
        }

        for target in targets {
            target.setContentScrollView(scrollView, for: .bottom)
        }
    }

    static func findVerticalContentScrollView(startingFrom view: UIView) -> UIScrollView? {
        var current: UIView? = view
        while let candidate = current {
            if let scrollView = candidate as? UIScrollView,
               isEligibleVerticalContentScrollView(scrollView) {
                return scrollView
            }
            if let scrollView = findVerticalContentScrollView(in: candidate) {
                return scrollView
            }
            current = candidate.superview
        }
        return nil
    }

    private static func findVerticalContentScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView,
           isEligibleVerticalContentScrollView(scrollView) {
            return scrollView
        }
        for subview in view.subviews {
            if let scrollView = findVerticalContentScrollView(in: subview) {
                return scrollView
            }
        }
        return nil
    }

    static func isEligibleVerticalContentScrollView(_ scrollView: UIScrollView) -> Bool {
        RootTabBarMinimizeScrollPresentation.isEligibleVerticalContentScrollView(
            isTableView: scrollView is UITableView,
            isPagingEnabled: scrollView.isPagingEnabled,
            contentWidth: scrollView.contentSize.width,
            boundsWidth: scrollView.bounds.width,
            contentHeight: scrollView.contentSize.height,
            boundsHeight: scrollView.bounds.height
        )
    }
}

private struct RootTabBarMinimizeScrollInstaller: UIViewRepresentable {
    let isActive: Bool

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
        context.coordinator.isActive = isActive
        guard isActive else { return }
        DispatchQueue.main.async {
            guard context.coordinator.isActive else { return }
            RootTabBarMinimizeScrollAssociator.associate(from: uiView)
        }
        // List / ScrollView hosts often attach one run-loop later (same timing as scroll-to-top).
        Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(32))
            guard context.coordinator.isActive else { return }
            RootTabBarMinimizeScrollAssociator.associate(from: uiView)
        }
    }

    final class Coordinator {
        var isActive = false
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

    /// Binds this scroll surface to root-tab minimize (**`.onScrollDown`**) when **`isActive`**.
    func associatesRootTabBarMinimizeScroll(isActive: Bool = true) -> some View {
        #if canImport(UIKit)
        overlay(alignment: .top) {
            RootTabBarMinimizeScrollInstaller(isActive: isActive)
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
    /// Shows a small accent spinner under the logbook header while Firebase reloads the feed.
    func logbookBuddyFeedPullToRefresh(
        topInset: CGFloat = 0,
        action: @escaping () async -> Void
    ) -> some View {
        modifier(LogbookBuddyFeedPullToRefreshModifier(topInset: topInset, action: action))
    }
}

/// Pull-to-refresh chrome for Buddy Feed — system pull gesture + visible in-flight spinner.
/// Keeps the feed locked (and the system refresh offset held) until the Firebase reload
/// and minimum hold finish, then releases scroll.
private struct LogbookBuddyFeedPullToRefreshModifier: ViewModifier {
    let topInset: CGFloat
    let action: () async -> Void

    @State private var isRefreshing = false

    func body(content: Content) -> some View {
        content
            // Hold the list still while the spinner runs; re-enable when refresh completes.
            .scrollDisabled(isRefreshing)
            .refreshable {
                await performRefresh()
            }
            .overlay(alignment: .top) {
                if isRefreshing {
                    GoDiveRotateLoadingIndicator(
                        accessibilityLabel: LogbookBuddyFeedPullToRefreshPresentation.spinnerAccessibilityLabel,
                        accessibilityIdentifier:
                            LogbookBuddyFeedPullToRefreshPresentation.spinnerAccessibilityIdentifier
                    )
                        .padding(.top, topInset + LogbookBuddyFeedPullToRefreshPresentation.spinnerTopPadding)
                        .transition(
                            .opacity.combined(
                                with: .scale(
                                    scale: LogbookBuddyFeedPullToRefreshPresentation.spinnerAppearScale
                                )
                            )
                        )
                }
            }
            .animation(
                .easeInOut(duration: LogbookBuddyFeedPullToRefreshPresentation.spinnerAnimationDuration),
                value: isRefreshing
            )
    }

    @MainActor
    private func performRefresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        LogbookBuddyFeedPullToRefreshPresentation.playRefreshTriggeredHaptic()
        defer { isRefreshing = false }

        let startedAt = Date()
        await action()
        let elapsed = Date().timeIntervalSince(startedAt)
        let remaining = LogbookBuddyFeedPullToRefreshPresentation.minimumHoldDurationSeconds - elapsed
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }
    }
}

/// Tokens for Buddy Feed pull-to-refresh in-flight chrome.
enum LogbookBuddyFeedPullToRefreshPresentation: Sendable {
    nonisolated static let spinnerTopPadding: CGFloat = AppTheme.Spacing.sm
    nonisolated static let spinnerAppearScale: CGFloat = 0.85
    nonisolated static let spinnerAnimationDuration: TimeInterval = 0.2
    /// Keep the pull / spinner visible at least this long before releasing the feed.
    nonisolated static let minimumHoldDurationSeconds: TimeInterval = 0.55
    nonisolated static let refreshHapticIntensity: CGFloat = 0.85
    nonisolated static let symbolName = GoDiveRotateLoadingPresentation.symbolName
    nonisolated static let symbolRotateSpeed = GoDiveRotateLoadingPresentation.rotateSpeed
    nonisolated static let spinnerAccessibilityIdentifier = "Logbook.BuddyFeed.RefreshSpinner"
    nonisolated static let spinnerAccessibilityLabel = "Refreshing buddy feed"

    /// Light medium impact when the user crosses the pull-to-refresh threshold.
    @MainActor
    static func playRefreshTriggeredHaptic() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: refreshHapticIntensity)
        #endif
    }
}
