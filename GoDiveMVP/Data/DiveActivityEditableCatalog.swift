import Foundation

/// Tab-specific editable field groupings for the dive overview panels.
enum DiveActivityEditableCatalog: Sendable {

    struct Section: Sendable, Identifiable {
        let id: String
        let title: String
        let fieldIDs: [DiveActivityEditableFieldID]
    }

    static func sections(for tab: DiveActivityEditablePanelTab) -> [Section] {
        switch tab {
        case .map:
            return [
                Section(id: "dive", title: "Dive", fieldIDs: [
                    .startTime, .durationMinutes, .maxDepthMeters, .averageDepthMeters,
                    .bottomTimeSeconds, .surfaceIntervalSeconds, .diveNumber,
                    .avgAscentRateMetersPerSecond, .profileSampleCount,
                ]),
                Section(id: "location", title: "Location", fieldIDs: [
                    .siteName, .locationName, .entryCoordinate, .linkedCatalogSite,
                ]),
                Section(id: "environment", title: "Water temperature", fieldIDs: [
                    .waterTempAvgCelsius, .waterTempMaxCelsius, .waterTempMinCelsius,
                ]),
                Section(id: "conditions", title: "Conditions", fieldIDs: [
                    .diveCurrentStrength, .surfaceCondition, .entryType, .diveVisibility,
                ]),
                Section(id: "operator", title: "Operator", fieldIDs: [
                    .diveOperatorName, .diveMasterName, .diveSignature,
                ]),
                Section(id: "buddies", title: "Buddies", fieldIDs: [.buddies]),
                Section(id: "notes", title: "Notes", fieldIDs: [.notes]),
                Section(id: "source", title: "Source & import", fieldIDs: [
                    .source, .sourceDiveId, .rawImportVersion,
                ]),
                Section(id: "record", title: "Record", fieldIDs: [.recordID, .ownerName]),
            ]
        case .tank:
            return [
                Section(id: "gas", title: "Gas & cylinder", fieldIDs: [
                    .gasType, .oxygenMix, .tankMaterial, .tankVolumeDescription,
                    .tankPressureStartPSI, .tankPressureEndPSI,
                ]),
                Section(id: "consumption", title: "Consumption rates", fieldIDs: [.avgSAC, .avgRMV]),
                Section(id: "profileGas", title: "Profile samples (gas)", fieldIDs: [.profileGasSampleStats]),
                Section(id: "equipment", title: "Equipment", fieldIDs: [.linkedEquipment]),
            ]
        }
    }

    static func label(for field: DiveActivityEditableFieldID) -> String {
        switch field {
        case .startTime: "Start"
        case .durationMinutes: "Duration"
        case .maxDepthMeters: "Max depth"
        case .averageDepthMeters: "Average depth"
        case .bottomTimeSeconds: "Bottom time"
        case .surfaceIntervalSeconds: "Surface interval"
        case .diveNumber: "Dive number"
        case .avgAscentRateMetersPerSecond: "Avg ascent rate"
        case .profileSampleCount: "Profile samples"
        case .siteName: "Site name"
        case .locationName: "Location"
        case .entryCoordinate: "Entry GPS"
        case .linkedCatalogSite: "Linked catalog site"
        case .waterTempAvgCelsius: "Average"
        case .waterTempMaxCelsius: "Maximum"
        case .waterTempMinCelsius: "Minimum"
        case .diveCurrentStrength: "Current"
        case .surfaceCondition: "Surface conditions"
        case .entryType: "Entry type"
        case .diveVisibility: "Visibility"
        case .diveOperatorName: "Operator"
        case .diveMasterName: "Divemaster"
        case .diveSignature: "Signature"
        case .notes: "Notes"
        case .buddies: "Buddies"
        case .gasType: "Gas"
        case .oxygenMix: "O₂ mix"
        case .tankMaterial: "Tank material"
        case .tankVolumeDescription: "Stored volume label"
        case .tankPressureStartPSI: "Beginning pressure"
        case .tankPressureEndPSI: "Ending pressure"
        case .avgSAC: "SAC"
        case .avgRMV: "RMV"
        case .profileGasSampleStats: "Cylinder pressure on profile"
        case .linkedEquipment: "Equipment"
        case .source: "Source"
        case .sourceDiveId: "Source dive ID"
        case .rawImportVersion: "Import / format"
        case .recordID: "Record ID"
        case .ownerName: "Owner"
        }
    }

    static func isEditable(_ field: DiveActivityEditableFieldID) -> Bool {
        switch field {
        case .profileSampleCount, .linkedCatalogSite, .profileGasSampleStats, .sourceDiveId,
             .recordID, .ownerName:
            return false
        default:
            return true
        }
    }

}
