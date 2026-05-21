import Foundation

/// Stable identifiers for dive overview fields (map / tank editable panels).
enum DiveActivityEditableFieldID: String, Identifiable, Sendable, CaseIterable, Hashable {
    case startTime
    case durationMinutes
    case maxDepthMeters
    case averageDepthMeters
    case bottomTimeSeconds
    case surfaceIntervalSeconds
    case diveNumber
    case avgAscentRateMetersPerSecond
    case profileSampleCount

    case siteName
    case locationName
    case entryCoordinate
    case linkedCatalogSite

    case waterTempAvgCelsius
    case waterTempMaxCelsius
    case waterTempMinCelsius

    case diveCurrentStrength
    case surfaceCondition
    case entryType
    case diveVisibility

    case diveOperatorName
    case diveMasterName
    case diveSignature
    case notes

    case buddies

    case gasType
    case oxygenMix
    case tankMaterial
    case tankVolumeDescription
    case tankPressureStartPSI
    case tankPressureEndPSI
    case avgSAC
    case avgRMV
    case profileGasSampleStats

    case linkedEquipment

    case source
    case sourceDiveId
    case rawImportVersion

    case recordID
    case ownerName

    var id: String { rawValue }
}

enum DiveActivityEditablePanelTab: Sendable {
    case map
    case tank
}
