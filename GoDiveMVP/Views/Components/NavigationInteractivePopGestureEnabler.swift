import SwiftUI
import UIKit

// MARK: - Leading-edge swipe back (system gesture)

/// **`NavigationStack`** is backed by **`UINavigationController`**. Hiding the bar with
/// **`toolbar(.hidden, for: .navigationBar)`** (see [Apple documentation](https://developer.apple.com/documentation/swiftui/view/toolbar(_:for:)-6jsmg))
/// effectively disables the edge pop: UIKit keeps **`interactivePopGestureRecognizer?.isEnabled`** on but installs a
/// **delegate** whose **`gestureRecognizerShouldBegin`** returns **`false`** when the system back affordance is hidden.
/// Re-applying **`isEnabled = true`** alone is not enough; assign **`interactivePopGestureRecognizer?.delegate`** to the
/// owning **`UINavigationController`** with a **`gestureRecognizerShouldBegin`** that only checks stack depth (same idea
/// as common “smart swipe back” UIKit snippets).
///
/// **`List`** / **`ScrollView`** often attach **`UIPanGestureRecognizer`**s that otherwise prevent the pop recognizer
/// from beginning alongside scrolling; **`gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)`** restores cooperation
/// at the left edge.
///
/// SwiftUI sometimes hosts **`UIViewControllerRepresentable`** anchors **without** a non-nil **`navigationController`**
/// reference; in that case we also patch any **foreground** navigation stacks whose depth is **> 1** (walks window roots).
///
/// As a last resort, **`goDiveLeadingEdgeSwipePopOverlay`** exposes a **narrow leading strip** that calls **`dismiss()`**
/// so **`NavigationStack`** still pops when UIKit’s recognizer never begins.
///
/// - Note: This is the same edge swipe the system uses when the bar is visible—not a custom full-screen pan.

final class InteractivePopGestureAnchorViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        applyInteractivePopFix()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyInteractivePopFix()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyInteractivePopFix()
    }

    fileprivate func applyInteractivePopFix() {
        if let nav = navigationController {
            Self.configureInteractivePop(on: nav)
        } else {
            for nav in Self.foregroundNavigationControllers(withStackDepthGreaterThan: 1) {
                Self.configureInteractivePop(on: nav)
            }
        }
    }

    private static func configureInteractivePop(on nav: UINavigationController) {
        guard let pop = nav.interactivePopGestureRecognizer else { return }
        pop.isEnabled = true
        pop.delegate = nav
    }

    /// Walks key window hierarchies so we still find stacks when this anchor’s **`navigationController`** is nil.
    private static func foregroundNavigationControllers(withStackDepthGreaterThan minCount: Int) -> [UINavigationController] {
        var seen = Set<ObjectIdentifier>()
        var result: [UINavigationController] = []
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            guard windowScene.activationState == .foregroundActive || windowScene.activationState == .foregroundInactive else { continue }
            for window in windowScene.windows where !window.isHidden && window.alpha > 0.01 {
                guard let root = window.rootViewController else { continue }
                collectNavigationControllers(from: root, minCount: minCount, seen: &seen, into: &result)
            }
        }
        return result
    }

    private static func collectNavigationControllers(
        from root: UIViewController,
        minCount: Int,
        seen: inout Set<ObjectIdentifier>,
        into result: inout [UINavigationController]
    ) {
        if let nav = root as? UINavigationController, nav.viewControllers.count > minCount {
            let id = ObjectIdentifier(nav)
            if !seen.contains(id) {
                seen.insert(id)
                result.append(nav)
            }
        }
        for child in root.children {
            collectNavigationControllers(from: child, minCount: minCount, seen: &seen, into: &result)
        }
        if let presented = root.presentedViewController {
            collectNavigationControllers(from: presented, minCount: minCount, seen: &seen, into: &result)
        }
    }
}

struct NavigationInteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> InteractivePopGestureAnchorViewController {
        InteractivePopGestureAnchorViewController()
    }

    func updateUIViewController(_ uiViewController: InteractivePopGestureAnchorViewController, context: Context) {
        uiViewController.applyInteractivePopFix()
    }
}

extension View {
    /// Restores **`UINavigationController`’s** leading-edge interactive pop after hiding the navigation bar for custom chrome.
    func navigationInteractivePopGestureForHiddenNavBar() -> some View {
        background {
            NavigationInteractivePopGestureEnabler()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
    }

    /// Leading **bezel** strip: **`highPriorityGesture`** + **`dismiss()`** so **`NavigationStack`** pops when UIKit’s edge recognizer never begins.
    func goDiveLeadingEdgeSwipePopOverlay(
        enabled: Bool = true,
        onWillDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(GoDiveLeadingEdgeSwipePopOverlayModifier(enabled: enabled, onWillDismiss: onWillDismiss))
    }
}

// MARK: - SwiftUI strip fallback (dismiss = pop)

private struct GoDiveLeadingEdgeSwipePopOverlayModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    let enabled: Bool
    let onWillDismiss: (() -> Void)?

    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            if enabled {
                Color.clear
                    .frame(width: GoDiveLeadingEdgeSwipePopMetrics.stripWidth)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        DragGesture(
                            minimumDistance: GoDiveLeadingEdgeSwipePopMetrics.minimumDragDistance,
                            coordinateSpace: .global
                        )
                        .onEnded { value in
                            guard GoDiveLeadingEdgeSwipePopGate.shouldCommitPop(
                                startLocationX: value.startLocation.x,
                                translation: value.translation
                            ) else { return }
                            onWillDismiss?()
                            dismiss()
                        }
                    )
            }
        }
    }
}

enum GoDiveLeadingEdgeSwipePopMetrics {
    /// Keeps the strip mostly in the **bezel** so it rarely competes with the custom back chevron (~44pt).
    static let stripWidth: CGFloat = 20
    static let maxStartXFromScreenLeading: CGFloat = 72
    static let minimumDragDistance: CGFloat = 28
    static let requiredHorizontalTranslation: CGFloat = 95
    static let maxVerticalDeviation: CGFloat = 130
}

enum GoDiveLeadingEdgeSwipePopGate {
    static func shouldCommitPop(startLocationX: CGFloat, translation: CGSize) -> Bool {
        startLocationX <= GoDiveLeadingEdgeSwipePopMetrics.maxStartXFromScreenLeading
            && translation.width >= GoDiveLeadingEdgeSwipePopMetrics.requiredHorizontalTranslation
            && abs(translation.height) <= GoDiveLeadingEdgeSwipePopMetrics.maxVerticalDeviation
    }
}

// MARK: - Pop gesture delegate (hidden bar + scroll views)

/// **`@retroactive`** silences the SDK warning: UIKit may add this conformance later; we intentionally replace the pop gesture’s delegate when the bar is hidden.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    /// Allows the interactive pop gesture when there is more than one controller, independent of the system back button visibility.
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer else { return true }
        return viewControllers.count > 1
    }

    /// Lets the screen-edge pop run together with scroll pans (`List`, `ScrollView`); otherwise the scroll view often wins.
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard let pop = interactivePopGestureRecognizer else { return false }
        let touchesPop = gestureRecognizer === pop || otherGestureRecognizer === pop
        guard touchesPop else { return false }
        let peer = gestureRecognizer === pop ? otherGestureRecognizer : gestureRecognizer
        guard peer !== pop else { return false }
        return peer is UIPanGestureRecognizer
    }
}
