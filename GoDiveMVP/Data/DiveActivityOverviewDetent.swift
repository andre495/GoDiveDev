import CoreGraphics

/// Resting heights for the dive overview **`.sheet`** (map + tank tabs).
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

    static func bottomObstructionHeight(
        layoutHeight: CGFloat,
        detent: Self,
        bottomSafeInset: CGFloat
    ) -> CGFloat {
        layoutHeight * detent.heightFraction + bottomSafeInset
    }

    var accessibilityDescription: String {
        DiveActivityOverviewPanelMetrics.accessibilityDetentDescription(for: heightFraction)
    }

    func nextTaller() -> Self? {
        guard let fraction = DiveActivityOverviewPanelMetrics.nextTallerDetent(after: heightFraction) else {
            return nil
        }
        return Self(fraction: fraction)
    }

    func nextShorter() -> Self? {
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

    private init?(fraction: CGFloat) {
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
