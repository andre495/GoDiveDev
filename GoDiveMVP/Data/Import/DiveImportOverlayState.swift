import Foundation

enum DiveImportOverlayState: Equatable {
    case hidden
    case importing(milestone: DiveImportMilestone, fraction: Double)
    case failed(String)

    /// Enters a milestone at its starting bar position.
    static func start(_ milestone: DiveImportMilestone) -> DiveImportOverlayState {
        .importing(milestone: milestone, fraction: milestone.startFraction)
    }

    /// Disables Add-activity tiles only while an import is actively running (not on failure).
    var disablesSourceButtons: Bool {
        switch self {
        case .hidden, .failed: return false
        case .importing: return true
        }
    }

    var allowsAbortingOnboardingImport: Bool {
        switch self {
        case .importing: return false
        case .hidden, .failed: return true
        }
    }
}

/// After **Complete**, keep the scrim up briefly so the success state reads before dismiss.
enum DiveImportSuccessTiming {
    static let sleepAfterCompleteBeforeDismiss: Duration = .milliseconds(800)
}
