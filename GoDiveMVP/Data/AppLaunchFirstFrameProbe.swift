import Foundation
#if canImport(QuartzCore)
import QuartzCore
#endif
#if canImport(UIKit)
import UIKit
#endif

/// One-shot first-frame probe for **`[LaunchTimeline] first_frame`**.
///
/// Proxy for “first screen drawn” after process start — not identical to MetricKit /
/// Organizer TTFF (which includes pre-main + launch storyboard), but useful for local deltas.
@MainActor
enum AppLaunchFirstFrameProbe {
    #if canImport(QuartzCore)
    private static var displayLink: CADisplayLink?
    #endif
    private static var didArm = false
    private static var didRecord = false

    /// Call once when the first UI scene is ready to draw (production root appear / active).
    static func armIfNeeded() {
        guard !didArm, !didRecord else { return }
        didArm = true
        #if canImport(QuartzCore) && canImport(UIKit)
        let link = CADisplayLink(target: DisplayLinkTarget.shared, selector: #selector(DisplayLinkTarget.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        #else
        DispatchQueue.main.async {
            recordFirstFrameIfNeeded()
        }
        #endif
    }

    fileprivate static func recordFirstFrameIfNeeded() {
        guard !didRecord else { return }
        didRecord = true
        #if canImport(QuartzCore)
        displayLink?.invalidate()
        displayLink = nil
        #endif
        AppLaunchTimelineLog.firstFrame()
    }

    #if canImport(QuartzCore) && canImport(UIKit)
    private final class DisplayLinkTarget: NSObject {
        static let shared = DisplayLinkTarget()

        @objc func tick() {
            AppLaunchFirstFrameProbe.recordFirstFrameIfNeeded()
        }
    }
    #endif
}
