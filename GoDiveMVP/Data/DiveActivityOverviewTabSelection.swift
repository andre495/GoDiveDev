import Foundation

/// Panel detent rules when switching dive overview icon tabs.
enum DiveActivityOverviewTabSelection: Sendable {
    /// **Map** and **tank** always open at the default (**medium**) detent — not the prior tab’s minimized state.
    static func overviewDetent(whenSelecting tab: DiveActivityTab) -> DiveActivityOverviewDetent? {
        switch tab {
        case .map, .tank:
            return DiveActivityOverviewDetent.defaultSelection
        case .camera:
            return nil
        }
    }
}
