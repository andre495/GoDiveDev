import CoreGraphics
import Observation

/// Per-frame overview sheet height channel for gesture-driven heroes (tank depth chart).
///
/// The page keeps its epsilon-throttled `@State` fraction for map / media consumers; this object
/// carries the **unthrottled** grabber value so only views that read it (the tank hero) re-evaluate
/// on every drag frame instead of invalidating the whole activity page.
@MainActor @Observable
final class DiveActivityOverviewLiveSheetState {
    /// Continuous sheet height fraction — resting detent value when idle, live value while dragging.
    /// Mutated inside `Transaction.disablesAnimations` during drag and inside the
    /// `.diveOverviewPanelDetent` spring on release so readers settle in sync with the panel.
    var heightFraction: CGFloat

    /// Sheet height fraction at the instant the grabber was released.
    /// Set by the panel in `onEnded` **before** the detent mutation, so detent-change handlers can
    /// distinguish a long drag (skip entrance replay) from a tap/programmatic detent change.
    /// Consumers read it once and reset it to `nil`.
    var dragReleaseHeightFraction: CGFloat?

    init(heightFraction: CGFloat = DiveActivityOverviewDetent.defaultSelection.heightFraction) {
        self.heightFraction = heightFraction
    }
}
