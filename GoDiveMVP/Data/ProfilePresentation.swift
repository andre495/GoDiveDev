import Foundation

/// Read-only copy for the **Profile** header.
enum ProfilePresentation: Sendable {
    static func diveActivityCountLabel(_ count: Int) -> String {
        switch count {
        case 0:
            return "No dives logged"
        case 1:
            return "1 dive"
        default:
            return "\(count) dives"
        }
    }
}
