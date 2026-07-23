import SwiftUI

/// Live overview panel height fraction (resting detent or grabber drag) for progressive map content reveal.
private struct DiveOverviewPanelHeightFractionKey: EnvironmentKey {
    static let defaultValue: CGFloat = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
}

extension EnvironmentValues {
    var diveOverviewPanelHeightFraction: CGFloat {
        get { self[DiveOverviewPanelHeightFractionKey.self] }
        set { self[DiveOverviewPanelHeightFractionKey.self] = newValue }
    }
}

extension Animation {
    /// Shared spring for embedded overview panel height + map panel content reveals.
    static var diveOverviewPanelDetent: Animation {
        .interactiveSpring(response: 0.38, dampingFraction: 0.88, blendDuration: 0.15)
    }
}
