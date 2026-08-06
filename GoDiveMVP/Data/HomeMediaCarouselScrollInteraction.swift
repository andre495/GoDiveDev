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
}

#if canImport(UIKit)
/// Installs a **`UITapGestureRecognizer`** on the Home carousel **`UIScrollView`**.
///
/// Uses **`cancelsTouchesInView = false`** + simultaneous recognition with the pan (not
/// **`require(toFail:)`**, which often prevents taps from ever firing on SwiftUI scroll views).
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
            onTap()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UIControl { return false }
                let name = String(describing: type(of: current))
                if name.contains("Button") {
                    return false
                }
                view = current.superview
            }
            return true
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
