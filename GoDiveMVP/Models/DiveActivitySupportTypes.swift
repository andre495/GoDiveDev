import Foundation

/// Kept **outside** **`DiveActivity.swift`** so value types are not Swift-6–inferred as **Main actor** along with **`@Model`** (fixes **`Equatable`** in **`#expect`** and cross-island concurrency).

enum DeviceSource: String, Codable, CaseIterable, Sendable {
    case garminMK3 = "Garmin MK3"
    case macDive = "MacDive"
    case manual = "Manual"
}

struct DiveCoordinate: Codable, Equatable, Sendable {
    var latitude: Double
    var longitude: Double

    /// Explicit **nonisolated** equality for Swift Testing **`#expect`** (Swift 6).
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

extension DeviceSource {
    /// **Overview** title when **`siteName`** is missing (imported dives without a named site).
    var overviewFallbackSiteTitle: String {
        switch self {
        case .garminMK3: "Garmin dive"
        case .macDive: "MacDive dive"
        case .manual: "Dive"
        }
    }
}
