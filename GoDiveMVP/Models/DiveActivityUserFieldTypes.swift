import Foundation

/// Manual logbook **current** strength (user-entered on dive overview).
enum DiveCurrentStrength: String, Codable, CaseIterable, Sendable, Identifiable {
    case none
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .none: "None"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

/// Manual **visibility** rating (user-entered).
enum DiveVisibilityRating: String, Codable, CaseIterable, Sendable, Identifiable {
    case poor
    case good
    case great

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .poor: "Poor"
        case .good: "Good"
        case .great: "Great"
        }
    }
}
