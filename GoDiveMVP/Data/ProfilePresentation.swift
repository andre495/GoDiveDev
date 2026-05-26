import Foundation

/// Read-only copy for the **Profile** header.
enum ProfilePresentation: Sendable {
    static func danInsuranceLabel(_ memberNumber: String) -> String {
        "DAN \(memberNumber)"
    }

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

    static func certificationCountLabel(_ count: Int) -> String {
        switch count {
        case 0:
            return "No certifications"
        case 1:
            return "1 certification"
        default:
            return "\(count) certifications"
        }
    }

    static func equipmentItemCountLabel(_ count: Int) -> String {
        switch count {
        case 0:
            return "No gear"
        case 1:
            return "1 item"
        default:
            return "\(count) items"
        }
    }
}
