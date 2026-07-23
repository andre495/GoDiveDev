import Foundation

/// Sub-screens on **`ViewSingleSnorkelActivity`** (map / heart rate / media).
nonisolated enum SnorkelActivityTab: CaseIterable, Hashable, Sendable {
    case map
    case heartRate
    case camera

    var systemImageName: String {
        switch self {
        case .map: "map"
        case .heartRate: "heart.fill"
        case .camera: "camera"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .map: "Map"
        case .heartRate: "Heart rate"
        case .camera: "Media"
        }
    }

    var accessibilityIdentifierSuffix: String {
        switch self {
        case .map: "map"
        case .heartRate: "heartRate"
        case .camera: "camera"
        }
    }
}
