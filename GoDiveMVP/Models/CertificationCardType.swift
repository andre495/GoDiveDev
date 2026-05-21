import Foundation

/// Card classification for a logged training credential (**certification** vs **specialty**).
enum CertificationCardType: String, CaseIterable, Codable, Sendable {
    case certification
    case specialty

    var displayName: String {
        switch self {
        case .certification: "Certification"
        case .specialty: "Specialty"
        }
    }
}
