import CoreGraphics

/// Resting heights for the dive overview bottom panel (map + tank tabs).
///
/// Kept free of **SwiftUI** so **`Equatable`** / **`Hashable`** stay **nonisolated** (Swift 6).
/// See **`DiveActivityOverviewDetent+Presentation.swift`** for **`PresentationDetent`** mapping.
enum DiveActivityOverviewDetent: CaseIterable, Equatable, Hashable, Sendable {
    case minimized
    case medium
    case large

    nonisolated var heightFraction: CGFloat {
        switch self {
        case .minimized:
            DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        case .medium:
            DiveActivityOverviewPanelMetrics.mediumHeightFraction
        case .large:
            DiveActivityOverviewPanelMetrics.largeHeightFraction
        }
    }

    static let defaultSelection: Self = .medium

    /// Map camera zoom / pin framing — **large** matches **medium** (map is mostly covered by the sheet).
    nonisolated var mapCameraDetent: Self {
        self == .large ? .medium : self
    }

    /// Reference layout for **`presentationDetent(screenHeight:bottomSafeInset:)`** round-trip tests.
    nonisolated static let presentationReferenceScreenHeight: CGFloat = 844
    nonisolated static let presentationReferenceBottomSafeInset: CGFloat = 34

    /// Sheet height in points — includes **`bottomSafeInset`** so the panel meets the physical bottom edge.
    nonisolated static func sheetHeight(
        for detent: Self,
        layoutHeight: CGFloat,
        bottomSafeInset: CGFloat
    ) -> CGFloat {
        sheetHeight(
            forHeightFraction: detent.heightFraction,
            layoutHeight: layoutHeight,
            bottomSafeInset: bottomSafeInset
        )
    }

    /// Continuous height while the grabber is moving (not quantized to resting detents).
    nonisolated static func sheetHeight(
        forHeightFraction fraction: CGFloat,
        layoutHeight: CGFloat,
        bottomSafeInset: CGFloat
    ) -> CGFloat {
        layoutHeight * fraction + bottomSafeInset
    }

    nonisolated static func bottomObstructionHeight(
        layoutHeight: CGFloat,
        detent: Self,
        bottomSafeInset: CGFloat
    ) -> CGFloat {
        sheetHeight(for: detent, layoutHeight: layoutHeight, bottomSafeInset: bottomSafeInset)
    }

    nonisolated var accessibilityDescription: String {
        DiveActivityOverviewPanelMetrics.accessibilityDetentDescription(for: heightFraction)
    }

    nonisolated func nextTaller() -> Self? {
        guard let fraction = DiveActivityOverviewPanelMetrics.nextTallerDetent(after: heightFraction) else {
            return nil
        }
        return Self(fraction: fraction)
    }

    nonisolated func nextShorter() -> Self? {
        guard let fraction = DiveActivityOverviewPanelMetrics.nextShorterDetent(after: heightFraction) else {
            return nil
        }
        return Self(fraction: fraction)
    }

    /// Explicit **nonisolated** equality for Swift Testing **`#expect`** (Swift 6).
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.minimized, .minimized), (.medium, .medium), (.large, .large):
            return true
        default:
            return false
        }
    }

    nonisolated func hash(into hasher: inout Hasher) {
        switch self {
        case .minimized: hasher.combine(0)
        case .medium: hasher.combine(1)
        case .large: hasher.combine(2)
        }
    }

    /// Maps a height fraction (e.g. after grabber drag) to the nearest resting detent.
    nonisolated static func nearest(toHeightFraction fraction: CGFloat) -> Self {
        if DiveActivityOverviewPanelMetrics.isMinimized(fraction) {
            return .minimized
        }
        if DiveActivityOverviewPanelMetrics.isExpanded(fraction) {
            return .large
        }
        if abs(fraction - DiveActivityOverviewPanelMetrics.mediumHeightFraction) < 0.03 {
            return .medium
        }
        return .medium
    }

    nonisolated private init?(fraction: CGFloat) {
        if DiveActivityOverviewPanelMetrics.isMinimized(fraction) {
            self = .minimized
        } else if DiveActivityOverviewPanelMetrics.isExpanded(fraction) {
            self = .large
        } else if abs(fraction - DiveActivityOverviewPanelMetrics.mediumHeightFraction) < 0.03 {
            self = .medium
        } else {
            return nil
        }
    }
}
