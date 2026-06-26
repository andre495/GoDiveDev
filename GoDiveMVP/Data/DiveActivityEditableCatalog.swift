import Foundation

/// Trailing control on a section header in the dive overview panels.
enum DiveActivityEditableSectionHeaderAction: Sendable, Equatable {
    case none
    /// Opens the buddies picker (add more).
    case add
    /// Opens a multi-field form sheet for editable rows in the section.
    case editForm
    /// Opens the equipment linker (tank tab).
    case manageEquipment

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none), (.add, .add), (.editForm, .editForm), (.manageEquipment, .manageEquipment):
            return true
        default:
            return false
        }
    }
}

/// Tab-specific editable field groupings for the dive overview panels.
enum DiveActivityEditableCatalog: Sendable {

    struct Section: Sendable, Identifiable {
        let id: String
        let title: String
        let fieldIDs: [DiveActivityEditableFieldID]
        /// When **`true`**, section appears only at the **large** overview detent (tank tab extras).
        var requiresLargeDetent: Bool = false
    }

    static func sections(
        for tab: DiveActivityEditablePanelTab,
        detent: DiveActivityOverviewDetent
    ) -> [Section] {
        let all = allSections(for: tab)
        guard detent != .large else { return all }
        return all.filter { !$0.requiresLargeDetent }
    }

    /// Map stats box edit target — not listed in **`sections(for: .map)`** but editable via the stats tile.
    static let mapDiveSummarySection = Section(
        id: "dive",
        title: "Dive",
        fieldIDs: [
            .startTime, .startTimeUTC, .timeZoneOffset,
            .durationMinutes, .maxDepthMeters, .averageDepthMeters,
            .bottomTimeSeconds, .surfaceIntervalSeconds, .diveNumber,
            .avgAscentRateMetersPerSecond, .profileSampleCount,
        ]
    )

    static func section(
        id: String,
        tab: DiveActivityEditablePanelTab,
        detent: DiveActivityOverviewDetent
    ) -> Section? {
        if tab == .map, id == mapDiveSummarySection.id {
            return mapDiveSummarySection
        }
        return sections(for: tab, detent: detent).first { $0.id == id }
    }

    static func mapStatsBoxShowsEditButton(for activity: DiveActivity) -> Bool {
        headerAction(for: mapDiveSummarySection, activity: activity) == .editForm
    }

    private static func allSections(for tab: DiveActivityEditablePanelTab) -> [Section] {
        switch tab {
        case .map:
            return [
                Section(id: "diveConditions", title: "Dive Conditions", fieldIDs: [
                    .waterTempAvgCelsius, .waterTempMaxCelsius, .waterTempMinCelsius,
                    .diveCurrentStrength, .surfaceCondition, .entryType, .diveVisibility,
                ]),
                Section(id: "buddies", title: "Buddies", fieldIDs: [.buddies]),
                Section(id: "notes", title: "Notes", fieldIDs: [.notes]),
            ]
        case .tank:
            return [
                Section(id: "gas", title: "Gas & cylinder", fieldIDs: [
                    .gasType, .oxygenMix, .tankMaterial, .tankVolumeDescription,
                    .tankPressureStartPSI, .tankPressureEndPSI,
                ]),
                Section(id: "consumption", title: "Consumption rates", fieldIDs: [.avgSAC, .avgRMV]),
                Section(id: "equipment", title: "Equipment", fieldIDs: [.linkedEquipment]),
                Section(id: "weights", title: "Weights", fieldIDs: [.diveWaterType, .diverWeightKilograms]),
                Section(
                    id: "operator",
                    title: "Operator",
                    fieldIDs: [.diveOperatorName, .diveMasterName, .diveSignature],
                    requiresLargeDetent: true
                ),
                Section(
                    id: "source",
                    title: "Source & import",
                    fieldIDs: [.source, .sourceDiveId, .rawImportVersion],
                    requiresLargeDetent: true
                ),
            ]
        }
    }

    static func label(for field: DiveActivityEditableFieldID) -> String {
        switch field {
        case .startTime: "Start (dive time)"
        case .startTimeUTC: "Start (UTC)"
        case .timeZoneOffset: "Timezone offset"
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
        case .diveWaterType: "Water type"
        case .diverWeightKilograms: "Diver weight"
        case .source: "Source"
        case .sourceDiveId: "Source dive ID"
        case .rawImportVersion: "Import / format"
        case .recordID: "Record ID"
        case .ownerName: "Owner"
        }
    }

    /// Dive metrics populated by file import — editable only on manually created dives.
    static let manualEntryOnlyFieldIDs: Set<DiveActivityEditableFieldID> = [
        .durationMinutes,
        .maxDepthMeters,
        .averageDepthMeters,
        .bottomTimeSeconds,
        .surfaceIntervalSeconds,
        .avgAscentRateMetersPerSecond,
    ]

    static func isManualEntryOnly(_ field: DiveActivityEditableFieldID) -> Bool {
        manualEntryOnlyFieldIDs.contains(field)
    }

    /// Whether the field can ever be edited in the app (ignores dive source).
    static func isEditable(_ field: DiveActivityEditableFieldID) -> Bool {
        switch field {
        case .profileSampleCount, .linkedCatalogSite, .profileGasSampleStats,
             .source, .sourceDiveId, .rawImportVersion,
             .startTimeUTC, .timeZoneOffset,
             .recordID, .ownerName,
             .avgSAC, .avgRMV:
            return false
        default:
            return true
        }
    }

    /// Whether the field can be edited for this dive (includes manual-only import restrictions).
    static func isEditable(_ field: DiveActivityEditableFieldID, for activity: DiveActivity) -> Bool {
        guard isEditable(field) else { return false }
        if isManualEntryOnly(field), activity.source != .manual {
            return false
        }
        return true
    }

    static func editableFields(in section: Section, for activity: DiveActivity) -> [DiveActivityEditableFieldID] {
        section.fieldIDs.filter { isEditable($0, for: activity) }
    }

    static func headerAction(
        for section: Section,
        activity: DiveActivity
    ) -> DiveActivityEditableSectionHeaderAction {
        switch section.id {
        case "buddies":
            return .add
        case "equipment":
            return .manageEquipment
        default:
            return editableFields(in: section, for: activity).isEmpty ? .none : .editForm
        }
    }

}
