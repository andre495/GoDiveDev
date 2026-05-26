import Foundation

/// User-selectable default cylinder size + material (**Settings**).
enum DefaultTankSize: String, CaseIterable, Sendable {
    case al80 = "AL80"
    case al63 = "AL63"
    case st100 = "ST100"
    case st120 = "ST120"

    /// Rated gas capacity at the surface (**cu ft**).
    nonisolated var ratedVolumeCubicFeet: Double {
        switch self {
        case .al80: 80
        case .al63: 63
        case .st100: 100
        case .st120: 120
        }
    }

    /// Persisted on **`DiveActivity.tankMaterial`** when import has no material.
    nonisolated var materialLabel: String {
        switch self {
        case .al80, .al63: "aluminum"
        case .st100, .st120: "steel"
        }
    }

    /// Short label for **Settings** picker (compact row + menu).
    nonisolated var settingsPickerTitle: String {
        rawValue
    }

    /// Material hint for accessibility / future menu subtitles.
    nonisolated var settingsPickerMaterialLabel: String {
        switch self {
        case .al80, .al63: "Aluminum"
        case .st100, .st120: "Steel"
        }
    }

    nonisolated var specification: DefaultTankSpecification {
        DefaultTankSpecification(size: self)
    }
}

/// Resolved rated volume + material for imports, RMV, and gas UI.
struct DefaultTankSpecification: Sendable, Equatable {
    let size: DefaultTankSize
    let ratedVolumeCubicFeet: Double
    let materialLabel: String

    nonisolated init(size: DefaultTankSize) {
        self.size = size
        ratedVolumeCubicFeet = size.ratedVolumeCubicFeet
        materialLabel = size.materialLabel
    }

    nonisolated var ratedVolumeSurfaceLiters: Double {
        ratedVolumeCubicFeet * DefaultTankSpecification.litersPerCubicFoot
    }

    /// Stored on **`DiveActivity.tankVolumeDescription`** at import.
    nonisolated var storedDescription: String {
        "\(Int(ratedVolumeCubicFeet.rounded())) cu ft (\(size.rawValue))"
    }

    nonisolated static let litersPerCubicFoot: Double = 28.316846592
}
