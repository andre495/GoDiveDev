import Foundation

/// Single-dive sub-screens shown from the top icon tab row on **`ViewSingleActivity`**.
nonisolated enum DiveActivityTab: CaseIterable, Hashable, Sendable {
    case map
    case tank
    case camera

    /// SF Symbol name when the tab uses **`Image(systemName:)`**; **`nil`** when **`assetImageName`** is set.
    var systemImageName: String? {
        switch self {
        case .map: "map"
        case .tank: nil
        case .camera: "camera"
        }
    }

    /// Asset catalog name (**template** intent) when not using SF Symbols.
    var assetImageName: String? {
        switch self {
        case .tank: "ScubaTankTab"
        default: nil
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .map: "Map"
        case .tank: "Tank"
        case .camera: "Media"
        }
    }

    var accessibilityIdentifierSuffix: String {
        switch self {
        case .map: "map"
        case .tank: "tank"
        case .camera: "camera"
        }
    }
}
