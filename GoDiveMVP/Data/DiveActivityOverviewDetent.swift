import CoreGraphics

/// Resting heights for the dive overview bottom panel (map + tank tabs).
///
/// Two detents only — **minimized** (compact) and **large** (blue-sheet-aligned). Kept free of **SwiftUI** so **`Equatable`** / **`Hashable`** stay **nonisolated** (Swift 6).
/// See **`DiveActivityOverviewDetent+Presentation.swift`** for **`PresentationDetent`** mapping.
enum DiveActivityOverviewDetent: CaseIterable, Equatable, Hashable, Sendable {
    case minimized
    case large

    nonisolated var heightFraction: CGFloat {
        switch self {
        case .minimized:
            DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        case .large:
            DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
        }
    }

    nonisolated func resolvedHeightFraction(in context: DiveActivityOverviewSheetLayoutContext) -> CGFloat {
        switch self {
        case .minimized:
            DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        case .large:
            DiveActivityOverviewPanelMetrics.largeHeightFraction(in: context)
        }
    }

    static let defaultSelection: Self = .large

    /// Map camera zoom / pin framing follows the resting overview detent.
    nonisolated var mapCameraDetent: Self { self }

    /// Pan/zoom on the dive overview map is enabled only at the low (**minimized**) sheet detent.
    nonisolated var allowsMapInteraction: Bool {
        self == .minimized
    }

    /// Reference layout for **`presentationDetent(…)`** round-trip tests.
    nonisolated static let presentationReferenceScreenHeight: CGFloat = 844
    nonisolated static let presentationReferenceScreenWidth: CGFloat = 393
    nonisolated static let presentationReferenceBottomSafeInset: CGFloat = 34

    /// Sheet height in points — includes **`bottomSafeInset`** so the panel meets the physical bottom edge.
    nonisolated static func sheetHeight(
        for detent: Self,
        layoutHeight: CGFloat,
        bottomSafeInset: CGFloat,
        screenWidth: CGFloat = presentationReferenceScreenWidth,
        topSafeInset: CGFloat = DiveActivityOverviewSheetLayoutContext.presentationReference.topSafeInset
    ) -> CGFloat {
        sheetHeight(
            forHeightFraction: detent.resolvedHeightFraction(
                in: DiveActivityOverviewSheetLayoutContext(
                    layoutHeight: layoutHeight,
                    screenWidth: screenWidth,
                    topSafeInset: topSafeInset,
                    bottomSafeInset: bottomSafeInset
                )
            ),
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
        bottomSafeInset: CGFloat,
        screenWidth: CGFloat = presentationReferenceScreenWidth,
        topSafeInset: CGFloat = DiveActivityOverviewSheetLayoutContext.presentationReference.topSafeInset
    ) -> CGFloat {
        sheetHeight(
            for: detent,
            layoutHeight: layoutHeight,
            bottomSafeInset: bottomSafeInset,
            screenWidth: screenWidth,
            topSafeInset: topSafeInset
        )
    }

    nonisolated var accessibilityDescription: String {
        DiveActivityOverviewPanelMetrics.accessibilityDetentDescription(for: heightFraction)
    }

    nonisolated func nextTaller() -> Self? {
        self == .minimized ? .large : nil
    }

    nonisolated func nextShorter() -> Self? {
        self == .large ? .minimized : nil
    }

    /// Explicit **nonisolated** equality for Swift Testing **`#expect`** (Swift 6).
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.minimized, .minimized), (.large, .large):
            return true
        default:
            return false
        }
    }

    nonisolated func hash(into hasher: inout Hasher) {
        switch self {
        case .minimized: hasher.combine(0)
        case .large: hasher.combine(1)
        }
    }

    /// Maps a height fraction (e.g. after grabber drag) to the nearest resting detent.
    nonisolated static func nearest(
        toHeightFraction fraction: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> Self {
        if DiveActivityOverviewPanelMetrics.isMinimized(fraction) {
            return .minimized
        }
        if DiveActivityOverviewPanelMetrics.isLarge(fraction, largeRestingFraction: largeRestingFraction) {
            return .large
        }
        let midpoint = (minimizedHeightFraction + largeRestingFraction) / 2
        return fraction < midpoint ? .minimized : .large
    }

    nonisolated private static var minimizedHeightFraction: CGFloat {
        DiveActivityOverviewPanelMetrics.minimizedHeightFraction
    }

    nonisolated private static var referenceLargeHeightFraction: CGFloat {
        DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
    }

    nonisolated private init?(fraction: CGFloat, largeRestingFraction: CGFloat) {
        if DiveActivityOverviewPanelMetrics.isMinimized(fraction) {
            self = .minimized
        } else if DiveActivityOverviewPanelMetrics.isLarge(fraction, largeRestingFraction: largeRestingFraction) {
            self = .large
        } else {
            return nil
        }
    }
}
