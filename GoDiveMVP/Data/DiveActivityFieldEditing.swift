import Foundation

/// Display strings and draft values for dive field editors.
enum DiveActivityFieldEditing {

    static func displayValue(
        for field: DiveActivityEditableFieldID,
        activity: DiveActivity,
        displayUnits: DiveDisplayUnitSystem,
        profileGasStats: DiveActivityTankPanelSummary.ProfilePressureStats
    ) -> String {
        switch field {
        case .startTime:
            return activity.formattedStartDateTime()
        case .startTimeUTC:
            return activity.formattedStartUTCDateTime()
        case .timeZoneOffset:
            return activity.formattedTimeZoneOffsetLabel()
        case .durationMinutes:
            return "\(activity.durationMinutes) min"
        case .maxDepthMeters:
            return DiveQuantityFormatting.depth(meters: activity.maxDepthMeters, system: displayUnits)
        case .averageDepthMeters:
            return formatOptionalDepth(activity.averageDepthMeters, displayUnits: displayUnits)
        case .bottomTimeSeconds, .surfaceIntervalSeconds:
            let seconds = field == .bottomTimeSeconds ? activity.bottomTimeSeconds : activity.surfaceIntervalSeconds
            return formatDurationSeconds(seconds)
        case .diveNumber:
            if activity.diveNumberExplicitlyNone { return "Hidden in logbook (−)" }
            return activity.diveNumberPlainLabel
        case .avgAscentRateMetersPerSecond:
            guard let rate = activity.avgAscentRateMetersPerSecond else { return "—" }
            switch displayUnits {
            case .metric:
                return String(format: "%.2f m/s", rate)
            case .imperial:
                let fpm = rate * 3.280839895013123 * 60
                return String(format: "%.1f ft/min", fpm)
            }
        case .profileSampleCount:
            return "\(activity.profilePoints.count)"
        case .siteName:
            return trimmed(activity.resolvedSiteName) ?? trimmed(activity.siteName) ?? "—"
        case .locationName:
            return trimmed(activity.locationName) ?? "—"
        case .entryCoordinate:
            return formatCoordinate(activity.entryCoordinate)
        case .linkedCatalogSite:
            if let site = activity.diveSite {
                return site.siteName
            }
            return "Not linked"
        case .waterTempAvgCelsius:
            return DiveQuantityFormatting.waterTemperature(celsius: activity.waterTempAvgCelsius, system: displayUnits)
        case .waterTempMaxCelsius:
            return DiveQuantityFormatting.waterTemperature(celsius: activity.waterTempMaxCelsius, system: displayUnits)
        case .waterTempMinCelsius:
            return DiveQuantityFormatting.waterTemperature(celsius: activity.waterTempMinCelsius, system: displayUnits)
        case .diveCurrentStrength:
            return activity.resolvedDiveCurrentStrength.displayTitle
        case .surfaceCondition:
            return trimmed(activity.surfaceCondition) ?? "—"
        case .entryType:
            return trimmed(activity.entryType) ?? "—"
        case .diveVisibility:
            return activity.diveVisibility?.displayTitle ?? "—"
        case .diveOperatorName:
            return trimmed(activity.diveOperatorName) ?? "—"
        case .diveMasterName:
            return trimmed(activity.diveMasterName) ?? "—"
        case .diveSignature:
            return DiveSignatureDataFormatting.hasDisplayableContent(activity.diveSignatureData) ? "" : "—"
        case .notes:
            return trimmed(activity.notes) ?? "—"
        case .buddies:
            if activity.buddies.isEmpty { return "—" }
            return activity.buddies.map(\.displayName).joined(separator: ", ")
        case .gasType:
            return activity.gasDetailsGasTypeLine
        case .oxygenMix:
            return activity.gasDetailsOxygenMixLine
        case .tankMaterial:
            return activity.gasDetailsTankTypeLine()
        case .tankVolumeDescription:
            return trimmed(activity.tankVolumeDescription)
                ?? activity.gasDetailsTankVolumeLine(displayUnits: displayUnits)
        case .tankPressureStartPSI:
            return activity.gasDetailsBeginningPressureLine(displayUnits: displayUnits)
        case .tankPressureEndPSI:
            return activity.gasDetailsEndingPressureLine(displayUnits: displayUnits)
        case .avgSAC:
            return activity.tankHeroSACRateLine(displayUnits: displayUnits) ?? "—"
        case .avgRMV:
            return activity.tankHeroRMVRateLine(displayUnits: displayUnits) ?? "—"
        case .profileGasSampleStats:
            if profileGasStats.sampleCount == 0 {
                return "No cylinder pressure on profile"
            }
            let min = DiveQuantityFormatting.cylinderPressure(fromPSI: profileGasStats.minPSI, system: displayUnits)
            let max = DiveQuantityFormatting.cylinderPressure(fromPSI: profileGasStats.maxPSI, system: displayUnits)
            return "\(profileGasStats.sampleCount) samples · \(min) – \(max)"
        case .linkedEquipment:
            let count = activity.equipmentItemIDs.count
            return count == 0 ? "—" : "\(count) item\(count == 1 ? "" : "s")"
        case .source:
            return activity.source.rawValue
        case .sourceDiveId:
            return trimmed(activity.sourceDiveId) ?? "—"
        case .rawImportVersion:
            return trimmed(activity.rawImportVersion) ?? "—"
        case .recordID:
            return activity.id.uuidString
        case .ownerName:
            return trimmed(activity.owner?.displayName) ?? "—"
        }
    }

    static func editorKind(for field: DiveActivityEditableFieldID) -> DiveActivityFieldEditorKind {
        switch field {
        case .startTime: .dateTime
        case .durationMinutes, .bottomTimeSeconds, .surfaceIntervalSeconds, .oxygenMix: .integer
        case .maxDepthMeters, .averageDepthMeters, .avgAscentRateMetersPerSecond,
             .waterTempAvgCelsius, .waterTempMaxCelsius, .waterTempMinCelsius,
             .tankPressureStartPSI, .tankPressureEndPSI, .avgSAC, .avgRMV: .decimal
        case .diveNumber: .diveNumber
        case .entryCoordinate: .coordinate
        case .diveCurrentStrength: .currentStrength
        case .diveVisibility: .visibility
        case .source: .source
        case .diveSignature: .signature
        case .notes: .multilineText
        case .buddies: .buddies
        case .linkedEquipment: .equipment
        case .linkedCatalogSite: .linkedSite
        case .surfaceCondition, .entryType, .diveOperatorName, .diveMasterName,
             .siteName, .locationName, .gasType, .tankMaterial, .tankVolumeDescription,
             .rawImportVersion: .shortText
        case .sourceDiveId, .profileSampleCount, .profileGasSampleStats,
             .startTimeUTC, .timeZoneOffset,
             .recordID, .ownerName: .readOnly
        }
    }

    // MARK: - Draft load / save

    static func loadDraft(
        for field: DiveActivityEditableFieldID,
        activity: DiveActivity,
        displayUnits: DiveDisplayUnitSystem
    ) -> DiveActivityFieldEditDraft {
        var draft = DiveActivityFieldEditDraft()
        switch field {
        case .startTime:
            draft.dateValue = activity.startTime
        case .durationMinutes:
            draft.text = String(activity.durationMinutes)
        case .maxDepthMeters:
            draft.text = formatDepthInput(activity.maxDepthMeters, displayUnits: displayUnits)
        case .averageDepthMeters:
            draft.text = formatOptionalDepthInput(activity.averageDepthMeters, displayUnits: displayUnits)
        case .bottomTimeSeconds:
            draft.text = activity.bottomTimeSeconds.map(String.init) ?? ""
        case .surfaceIntervalSeconds:
            draft.text = activity.surfaceIntervalSeconds.map(String.init) ?? ""
        case .diveNumber:
            draft.text = activity.diveNumber.map(String.init) ?? ""
            draft.hideDiveNumber = activity.diveNumberExplicitlyNone
        case .avgAscentRateMetersPerSecond:
            draft.text = formatAscentInput(activity.avgAscentRateMetersPerSecond, displayUnits: displayUnits)
        case .entryCoordinate:
            if let c = activity.entryCoordinate {
                draft.latitudeText = String(format: "%.5f", c.latitude)
                draft.longitudeText = String(format: "%.5f", c.longitude)
            }
        case .diveCurrentStrength:
            draft.currentStrength = activity.resolvedDiveCurrentStrength
        case .diveVisibility:
            draft.visibility = activity.diveVisibility
        case .source:
            draft.source = activity.source
        case .notes:
            draft.text = activity.notes ?? ""
        case .oxygenMix:
            draft.text = activity.oxygenMix.map { String(Int($0.rounded())) } ?? ""
        case .tankPressureStartPSI:
            draft.text = formatPressureInput(activity.tankPressureStartPSI, displayUnits: displayUnits)
        case .tankPressureEndPSI:
            draft.text = formatPressureInput(activity.tankPressureEndPSI, displayUnits: displayUnits)
        case .avgSAC:
            draft.text = formatSACInput(activity.avgSAC, displayUnits: displayUnits)
        case .avgRMV:
            draft.text = formatRMVInput(activity.avgRMV, displayUnits: displayUnits)
        case .waterTempAvgCelsius:
            draft.text = formatTempInput(activity.waterTempAvgCelsius, displayUnits: displayUnits)
        case .waterTempMaxCelsius:
            draft.text = formatTempInput(activity.waterTempMaxCelsius, displayUnits: displayUnits)
        case .waterTempMinCelsius:
            draft.text = formatTempInput(activity.waterTempMinCelsius, displayUnits: displayUnits)
        case .siteName, .locationName, .surfaceCondition, .entryType,
             .diveOperatorName, .diveMasterName, .gasType, .tankMaterial,
             .tankVolumeDescription, .rawImportVersion:
            draft.text = stringFieldValue(field, activity: activity)
        default:
            break
        }
        return draft
    }

    static func applyDraft(
        _ draft: DiveActivityFieldEditDraft,
        for field: DiveActivityEditableFieldID,
        to activity: DiveActivity,
        displayUnits: DiveDisplayUnitSystem
    ) {
        switch field {
        case .startTime:
            if let date = draft.dateValue { activity.startTime = date }
        case .durationMinutes:
            if let minutes = DiveActivityFieldValueParsing.parseInt(draft.text) {
                activity.durationMinutes = max(0, minutes)
            }
        case .maxDepthMeters:
            if let meters = DiveActivityFieldValueParsing.parseDepthMeters(draft.text, displayUnits: displayUnits) {
                activity.maxDepthMeters = max(0, meters)
            }
        case .averageDepthMeters:
            activity.averageDepthMeters = DiveActivityFieldValueParsing.parseDepthMeters(draft.text, displayUnits: displayUnits)
        case .bottomTimeSeconds:
            activity.bottomTimeSeconds = DiveActivityFieldValueParsing.parseInt(draft.text)
        case .surfaceIntervalSeconds:
            activity.surfaceIntervalSeconds = DiveActivityFieldValueParsing.parseInt(draft.text)
        case .diveNumber:
            activity.diveNumberExplicitlyNone = draft.hideDiveNumber
            if draft.hideDiveNumber {
                activity.diveNumber = nil
            } else if let number = DiveActivityFieldValueParsing.parseInt(draft.text) {
                activity.diveNumber = max(1, number)
            }
        case .avgAscentRateMetersPerSecond:
            activity.avgAscentRateMetersPerSecond = DiveActivityFieldValueParsing.parseAscentRateMetersPerSecond(
                draft.text,
                displayUnits: displayUnits
            )
        case .siteName:
            activity.siteName = trimmedOptional(draft.text)
        case .locationName:
            activity.locationName = trimmedOptional(draft.text)
        case .entryCoordinate:
            activity.entryCoordinate = DiveActivityFieldValueParsing.parseCoordinate(
                latitudeText: draft.latitudeText,
                longitudeText: draft.longitudeText
            )
        case .waterTempAvgCelsius:
            activity.waterTempAvgCelsius = DiveActivityFieldValueParsing.parseWaterTempCelsius(draft.text, displayUnits: displayUnits)
        case .waterTempMaxCelsius:
            activity.waterTempMaxCelsius = DiveActivityFieldValueParsing.parseWaterTempCelsius(draft.text, displayUnits: displayUnits)
        case .waterTempMinCelsius:
            activity.waterTempMinCelsius = DiveActivityFieldValueParsing.parseWaterTempCelsius(draft.text, displayUnits: displayUnits)
        case .diveCurrentStrength:
            activity.resolvedDiveCurrentStrength = draft.currentStrength
        case .surfaceCondition:
            activity.surfaceCondition = trimmedOptional(draft.text)
        case .entryType:
            activity.entryType = trimmedOptional(draft.text)
        case .diveVisibility:
            activity.diveVisibility = draft.visibility
        case .diveOperatorName:
            activity.diveOperatorName = trimmedOptional(draft.text)
        case .diveMasterName:
            activity.diveMasterName = trimmedOptional(draft.text)
        case .notes:
            activity.notes = trimmedOptional(draft.text)
        case .gasType:
            activity.gasType = trimmedOptional(draft.text)
        case .oxygenMix:
            if let percent = DiveActivityFieldValueParsing.parseDouble(draft.text) {
                activity.oxygenMix = percent
            } else {
                activity.oxygenMix = nil
            }
        case .tankMaterial:
            activity.tankMaterial = trimmedOptional(draft.text)
        case .tankVolumeDescription:
            activity.tankVolumeDescription = trimmedOptional(draft.text)
        case .tankPressureStartPSI:
            activity.tankPressureStartPSI = DiveActivityFieldValueParsing.parsePressurePSI(draft.text, displayUnits: displayUnits)
        case .tankPressureEndPSI:
            activity.tankPressureEndPSI = DiveActivityFieldValueParsing.parsePressurePSI(draft.text, displayUnits: displayUnits)
        case .avgSAC:
            activity.avgSAC = DiveActivityFieldValueParsing.parseSACPSIPerMinute(draft.text, displayUnits: displayUnits)
        case .avgRMV:
            activity.avgRMV = DiveActivityFieldValueParsing.parseRMVLitersPerMinute(draft.text, displayUnits: displayUnits)
        case .source:
            activity.source = draft.source
        case .rawImportVersion:
            activity.rawImportVersion = trimmedOptional(draft.text)
        case .diveSignature, .buddies, .linkedEquipment, .linkedCatalogSite, .sourceDiveId,
             .startTimeUTC, .timeZoneOffset,
             .profileSampleCount, .profileGasSampleStats, .recordID, .ownerName:
            break
        }
    }

    // MARK: - Private formatting

    private static func trimmed(_ value: String?) -> String? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return raw
    }

    private static func trimmedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func formatDurationSeconds(_ seconds: Int?) -> String {
        guard let seconds, seconds > 0 else { return "—" }
        if seconds < 60 { return "\(seconds) s" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        if remainder == 0 { return "\(minutes) min" }
        return "\(minutes) min \(remainder) s"
    }

    private static func formatCoordinate(_ coordinate: DiveCoordinate?) -> String {
        guard let coordinate, DiveMapCoordinateResolver.isUsable(coordinate) else { return "—" }
        return String(format: "%.5f°, %.5f°", coordinate.latitude, coordinate.longitude)
    }

    private static func formatOptionalDepth(_ meters: Double?, displayUnits: DiveDisplayUnitSystem) -> String {
        guard let meters else { return "—" }
        return DiveQuantityFormatting.depth(meters: meters, system: displayUnits)
    }

    private static func formatDepthInput(_ meters: Double, displayUnits: DiveDisplayUnitSystem) -> String {
        switch displayUnits {
        case .metric: return String(format: "%.1f", meters)
        case .imperial: return String(format: "%.1f", meters * 3.280839895013123)
        }
    }

    private static func formatOptionalDepthInput(_ meters: Double?, displayUnits: DiveDisplayUnitSystem) -> String {
        guard let meters else { return "" }
        return formatDepthInput(meters, displayUnits: displayUnits)
    }

    private static func formatPressureInput(_ psi: Double?, displayUnits: DiveDisplayUnitSystem) -> String {
        guard let psi else { return "" }
        switch displayUnits {
        case .metric: return String(format: "%.1f", psi / 14.5037738007)
        case .imperial: return String(format: "%.0f", psi.rounded())
        }
    }

    private static func formatTempInput(_ celsius: Double?, displayUnits: DiveDisplayUnitSystem) -> String {
        guard let celsius else { return "" }
        switch displayUnits {
        case .metric: return String(format: "%.1f", celsius)
        case .imperial: return String(format: "%.1f", celsius * 9.0 / 5.0 + 32.0)
        }
    }

    private static func formatAscentInput(_ rate: Double?, displayUnits: DiveDisplayUnitSystem) -> String {
        guard let rate else { return "" }
        switch displayUnits {
        case .metric: return String(format: "%.2f", rate)
        case .imperial: return String(format: "%.1f", rate * 3.280839895013123 * 60)
        }
    }

    private static func formatSACInput(_ sac: Double?, displayUnits: DiveDisplayUnitSystem) -> String {
        guard let sac else { return "" }
        switch displayUnits {
        case .metric: return String(format: "%.1f", sac / 14.5037738007)
        case .imperial: return String(format: "%.1f", sac)
        }
    }

    private static func formatRMVInput(_ rmv: Double?, displayUnits: DiveDisplayUnitSystem) -> String {
        guard let rmv else { return "" }
        switch displayUnits {
        case .metric: return String(format: "%.1f", rmv)
        case .imperial: return String(format: "%.2f", rmv * 0.0353146667214888)
        }
    }

    private static func stringFieldValue(_ field: DiveActivityEditableFieldID, activity: DiveActivity) -> String {
        switch field {
        case .siteName: return activity.siteName ?? ""
        case .locationName: return activity.locationName ?? ""
        case .surfaceCondition: return activity.surfaceCondition ?? ""
        case .entryType: return activity.entryType ?? ""
        case .diveOperatorName: return activity.diveOperatorName ?? ""
        case .diveMasterName: return activity.diveMasterName ?? ""
        case .gasType: return activity.gasType ?? ""
        case .tankMaterial: return activity.tankMaterial ?? ""
        case .tankVolumeDescription: return activity.tankVolumeDescription ?? ""
        case .sourceDiveId: return activity.sourceDiveId ?? ""
        case .rawImportVersion: return activity.rawImportVersion ?? ""
        default: return ""
        }
    }
}

enum DiveActivityFieldEditorKind: Sendable {
    case shortText
    case multilineText
    case integer
    case decimal
    case dateTime
    case coordinate
    case diveNumber
    case currentStrength
    case visibility
    case source
    case signature
    case buddies
    case equipment
    case linkedSite
    case readOnly
}

struct DiveActivityFieldEditDraft: Sendable {
    var text: String = ""
    var latitudeText: String = ""
    var longitudeText: String = ""
    var dateValue: Date?
    var hideDiveNumber: Bool = false
    var currentStrength: DiveCurrentStrength = .none
    var visibility: DiveVisibilityRating?
    var source: DiveSource = .manual
}
