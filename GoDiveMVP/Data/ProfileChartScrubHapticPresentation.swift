import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Light selection ticks while scrubbing depth / heart-rate profile charts.
enum ProfileChartScrubHapticPresentation: Sendable {
    /// Cap fire rate so dense profiles do not saturate the Taptic Engine (~22 Hz).
    nonisolated static let minimumIntervalSeconds: TimeInterval = 0.045

    nonisolated static func shouldPlayScrubHaptic(
        isUITest: Bool = GoDiveUITestConfiguration.isActive
    ) -> Bool {
        !isUITest
    }

    /// Fires only when the scrub line lands on a **new** sample and enough time has passed.
    nonisolated static func shouldFireHaptic(
        forSampleIndex newIndex: Int?,
        previousSampleIndex: Int?,
        elapsedSinceLastHapticSeconds: TimeInterval,
        minimumIntervalSeconds: TimeInterval = minimumIntervalSeconds
    ) -> Bool {
        guard let newIndex else { return false }
        guard newIndex != previousSampleIndex else { return false }
        return elapsedSinceLastHapticSeconds >= minimumIntervalSeconds
    }
}

/// Reusable generator + throttle state for profile-chart scrub gestures.
@MainActor
final class ProfileChartScrubHapticPlayer {
    #if canImport(UIKit)
    private let generator = UISelectionFeedbackGenerator()
    #endif
    private var lastSampleIndex: Int?
    private var lastHapticAt: CFAbsoluteTime = -.infinity
    private var didPrepare = false

    func playIfNeeded(forSampleIndex index: Int?) {
        guard let index else {
            lastSampleIndex = nil
            return
        }
        guard ProfileChartScrubHapticPresentation.shouldPlayScrubHaptic() else {
            lastSampleIndex = index
            return
        }

        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = now - lastHapticAt
        guard ProfileChartScrubHapticPresentation.shouldFireHaptic(
            forSampleIndex: index,
            previousSampleIndex: lastSampleIndex,
            elapsedSinceLastHapticSeconds: elapsed
        ) else {
            // Advance the tracked index while rate-limited so a fast scrub does not
            // queue a burst of catch-up ticks after the window opens.
            lastSampleIndex = index
            return
        }

        #if canImport(UIKit)
        if !didPrepare {
            generator.prepare()
            didPrepare = true
        }
        generator.selectionChanged()
        generator.prepare()
        #endif

        lastSampleIndex = index
        lastHapticAt = now
    }

    func reset() {
        lastSampleIndex = nil
        lastHapticAt = -.infinity
    }
}
