import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Home featured-media paging interaction — keep **`ScrollView`** pans primary; open media on true taps.
enum HomeMediaCarouselScrollInteractionPresentation: Sendable {
    /// Prefer UIKit tap on the paging **`UIScrollView`** over SwiftUI tap gestures that fight pans.
    nonisolated static let usesUIKitScrollViewTapInstaller = true

    /// Eager **`HStack`** (not **`LazyHStack`**) — carousel is capped at **`carouselLimit`** and lazy
    /// materialization was dropping forward-page pans.
    nonisolated static let usesEagerHorizontalStackForPaging = true

    /// UIKit / SwiftUI hosting class-name tokens that own the tap (dive link, fish, buddy, etc.).
    /// Open-media must not also fire for those hits.
    nonisolated static let openMediaExcludedViewClassNameTokens: [String] = [
        "Button",
        "UIButton",
        "UIControl",
        "UISwitch",
        "UISlider",
        "UITextField",
        "UITextView",
    ]

    /// Whether a touch sitting on **`viewClassName`** should skip open-media (chrome owns the tap).
    nonisolated static func viewClassNameExcludesOpenMediaTap(_ viewClassName: String) -> Bool {
        openMediaExcludedViewClassNameTokens.contains { token in
            viewClassName.localizedCaseInsensitiveContains(token)
        }
    }

    /// Open-media yields to another recognizer when that recognizer is a control tap (not the pager pan).
    nonisolated static func openMediaTapShouldRequireFailure(
        ofOtherGestureClassName otherClassName: String,
        otherIsTapGesture: Bool,
        otherIsPanGesture: Bool,
        otherViewIsPagingScrollView: Bool
    ) -> Bool {
        if otherViewIsPagingScrollView { return false }
        if otherIsPanGesture { return false }
        if otherIsTapGesture { return true }
        return otherClassName.localizedCaseInsensitiveContains("Button")
            || otherClassName.localizedCaseInsensitiveContains("TapGesture")
    }

    /// Walked view-class names from the touch target up to (but not including) the paging scroll view.
    nonisolated static func shouldIgnoreOpenMediaTap(
        touchingViewClassNames: [String],
        encounteredNestedScrollView: Bool,
        hasCompetingTapRecognizer: Bool
    ) -> Bool {
        if encounteredNestedScrollView { return true }
        if hasCompetingTapRecognizer { return true }
        return touchingViewClassNames.contains(where: viewClassNameExcludesOpenMediaTap)
    }
}

#if canImport(UIKit)
/// Installs a **`UITapGestureRecognizer`** on the Home carousel **`UIScrollView`**.
///
/// Uses **`cancelsTouchesInView = false`** + simultaneous recognition with the pan (not
/// **`require(toFail:)`** on the pan, which often prevents taps from ever firing on SwiftUI
/// scroll views). Chrome buttons win via **`shouldReceive`** exclusion + requiring failure of
/// competing tap / button recognizers.
struct HomeMediaCarouselScrollTapInstaller: UIViewRepresentable {
    var onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> UIView {
        let view = PassthroughView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.scheduleAttach(from: uiView)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: () -> Void
        private weak var scrollView: UIScrollView?
        private weak var tapRecognizer: UITapGestureRecognizer?
        private var attachWorkItem: DispatchWorkItem?

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        func scheduleAttach(from anchor: UIView) {
            attachWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self, weak anchor] in
                guard let self, let anchor else { return }
                self.attachIfNeeded(from: anchor)
            }
            attachWorkItem = work
            // Layout may not have produced the UIScrollView on the first pass.
            DispatchQueue.main.async(execute: work)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
        }

        func detach() {
            attachWorkItem?.cancel()
            if let tapRecognizer, let scrollView {
                scrollView.removeGestureRecognizer(tapRecognizer)
            }
            tapRecognizer = nil
            scrollView = nil
        }

        private func attachIfNeeded(from anchor: UIView) {
            guard let scroll = Self.findHorizontalScrollView(near: anchor) else { return }
            if scrollView === scroll, tapRecognizer != nil { return }

            if let previousTap = tapRecognizer {
                scrollView?.removeGestureRecognizer(previousTap)
            }

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            scroll.addGestureRecognizer(tap)
            scrollView = scroll
            tapRecognizer = tap
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            guard let scrollView else {
                onTap()
                return
            }
            let point = recognizer.location(in: scrollView)
            if let hit = scrollView.hitTest(point, with: nil),
               Self.shouldIgnoreOpenMedia(for: hit, pagingScrollView: scrollView, tapRecognizer: recognizer) {
                return
            }
            onTap()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Stay simultaneous with the pager pan; do not race chrome button taps.
            if otherGestureRecognizer is UIPanGestureRecognizer { return true }
            if otherGestureRecognizer is UITapGestureRecognizer { return false }
            let name = String(describing: type(of: otherGestureRecognizer))
            if name.localizedCaseInsensitiveContains("Button")
                || name.localizedCaseInsensitiveContains("TapGesture") {
                return false
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard gestureRecognizer === tapRecognizer else { return false }
            let otherName = String(describing: type(of: otherGestureRecognizer))
            return HomeMediaCarouselScrollInteractionPresentation.openMediaTapShouldRequireFailure(
                ofOtherGestureClassName: otherName,
                otherIsTapGesture: otherGestureRecognizer is UITapGestureRecognizer,
                otherIsPanGesture: otherGestureRecognizer is UIPanGestureRecognizer,
                otherViewIsPagingScrollView: otherGestureRecognizer.view === scrollView
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            guard let scrollView else { return true }
            guard let touchView = touch.view else { return true }
            return !Self.shouldIgnoreOpenMedia(
                for: touchView,
                pagingScrollView: scrollView,
                tapRecognizer: tapRecognizer
            )
        }

        private static func shouldIgnoreOpenMedia(
            for startView: UIView,
            pagingScrollView: UIScrollView,
            tapRecognizer: UIGestureRecognizer?
        ) -> Bool {
            var classNames: [String] = []
            var encounteredNestedScrollView = false
            var hasCompetingTapRecognizer = false
            var current: UIView? = startView

            while let view = current {
                if view === pagingScrollView { break }

                if view is UIControl {
                    return true
                }
                if view is UIScrollView {
                    encounteredNestedScrollView = true
                }

                let name = NSStringFromClass(type(of: view))
                classNames.append(name)

                if let recognizers = view.gestureRecognizers {
                    for recognizer in recognizers {
                        guard recognizer !== tapRecognizer else { continue }
                        if recognizer is UITapGestureRecognizer {
                            hasCompetingTapRecognizer = true
                        }
                        let gestureName = String(describing: type(of: recognizer))
                        if gestureName.localizedCaseInsensitiveContains("Button")
                            || gestureName.localizedCaseInsensitiveContains("TapGesture") {
                            hasCompetingTapRecognizer = true
                        }
                    }
                }

                current = view.superview
            }

            return HomeMediaCarouselScrollInteractionPresentation.shouldIgnoreOpenMediaTap(
                touchingViewClassNames: classNames,
                encounteredNestedScrollView: encounteredNestedScrollView,
                hasCompetingTapRecognizer: hasCompetingTapRecognizer
            )
        }

        private static func findHorizontalScrollView(near anchor: UIView) -> UIScrollView? {
            var current: UIView? = anchor
            while let view = current {
                if let scroll = view as? UIScrollView, isHorizontalScroller(scroll) {
                    return scroll
                }
                current = view.superview
            }

            current = anchor.superview
            while let view = current {
                if let scroll = firstHorizontalScrollView(in: view) {
                    return scroll
                }
                current = view.superview
            }
            return nil
        }

        private static func isHorizontalScroller(_ scroll: UIScrollView) -> Bool {
            // Include single-slide pages (content width ≈ bounds) — still the Home pager.
            let widerOrEqual = scroll.contentSize.width + 0.5 >= scroll.bounds.width
            let notVerticalOnly = scroll.contentSize.height <= scroll.bounds.height + 1
            return widerOrEqual && notVerticalOnly && scroll.bounds.width > 1
        }

        private static func firstHorizontalScrollView(in root: UIView) -> UIScrollView? {
            var queue: [UIView] = root.subviews
            var index = 0
            while index < queue.count {
                let view = queue[index]
                index += 1
                if let scroll = view as? UIScrollView, isHorizontalScroller(scroll) {
                    return scroll
                }
                queue.append(contentsOf: view.subviews)
            }
            return nil
        }
    }
}

/// Never claims hits — only anchors the installer in the SwiftUI hierarchy.
private final class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}
#endif
