import Foundation

/// Panel detent rules when switching dive overview icon tabs.
enum DiveActivityOverviewTabSelection: Sendable {
    /// **Map**, **tank**, and **Media** open at the default (**large**) detent.
    static func overviewDetent(whenSelecting tab: DiveActivityTab) -> DiveActivityOverviewDetent? {
        switch tab {
        case .map, .tank, .camera:
            return DiveActivityOverviewDetent.defaultSelection
        }
    }

    /// **Map**, **heart rate**, and **media** on snorkel detail — same resting detents as dive.
    static func overviewDetent(whenSelectingSnorkel tab: SnorkelActivityTab) -> DiveActivityOverviewDetent? {
        switch tab {
        case .map, .heartRate, .camera:
            return DiveActivityOverviewDetent.defaultSelection
        }
    }
}
