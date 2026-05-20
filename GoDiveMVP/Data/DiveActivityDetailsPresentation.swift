import Foundation

/// User-facing labels and formatted values for every persisted **`DiveActivity`** field.
enum DiveActivityDetailsPresentation: Sendable {

    struct Row: Sendable, Identifiable {
        let id: String
        let label: String
        let value: String
    }

    struct Section: Sendable, Identifiable {
        let id: String
        let title: String
        let rows: [Row]
    }

    static func sections(
        for activity: DiveActivity,
        displayUnits: DiveDisplayUnitSystem,
        defaultTank: DefaultTankSpecification = DiveActivityTankDefaults.resolvedSpecification()
    ) -> [Section] {
        [
            diveSection(activity, displayUnits: displayUnits),
            locationSection(activity),
            environmentSection(activity, displayUnits: displayUnits),
            gasAndTankSection(activity, displayUnits: displayUnits, defaultTank: defaultTank),
            userLogSection(activity),
            buddiesSection(activity),
            equipmentSection(activity),
            sourceSection(activity),
            recordSection(activity),
        ].filter { !$0.rows.isEmpty }
    }

    // MARK: - Sections

    private static func diveSection(
        _ activity: DiveActivity,
        displayUnits: DiveDisplayUnitSystem
    ) -> Section {
        var rows: [Row] = [
            row("startTime", "Start", formatDateTime(activity.startTime)),
            row("durationMinutes", "Duration", "\(activity.durationMinutes) min"),
            row("maxDepthMeters", "Max depth", DiveQuantityFormatting.depth(meters: activity.maxDepthMeters, system: displayUnits)),
        ]
        if let avg = activity.averageDepthMeters {
            rows.append(row("averageDepthMeters", "Average depth", DiveQuantityFormatting.depth(meters: avg, system: displayUnits)))
        }
        rows.append(row("bottomTimeSeconds", "Bottom time", formatDurationSeconds(activity.bottomTimeSeconds)))
        rows.append(row("surfaceIntervalSeconds", "Surface interval", formatDurationSeconds(activity.surfaceIntervalSeconds)))
        rows.append(row("diveNumber", "Dive number", activity.diveNumberPlainLabel))
        if activity.diveNumberExplicitlyNone {
            rows.append(row("diveNumberExplicitlyNone", "Number in logbook", "Hidden (−)"))
        }
        if let ascent = activity.avgAscentRateMetersPerSecond {
            rows.append(row("avgAscentRateMetersPerSecond", "Avg ascent rate", formatAscentRate(metersPerSecond: ascent, system: displayUnits)))
        }
        rows.append(row("profilePoints.count", "Profile samples", "\(activity.profilePoints.count)"))
        return Section(id: "dive", title: "Dive", rows: rows)
    }

    private static func locationSection(_ activity: DiveActivity) -> Section {
        var rows: [Row] = []
        if let site = trimmed(activity.resolvedSiteName) {
            rows.append(row("site", "Site", site))
        } else if let imported = trimmed(activity.siteName) {
            rows.append(row("siteName", "Import site", imported))
        }
        if let location = trimmed(activity.locationName) {
            rows.append(row("locationName", "Location", location))
        }
        if let entry = activity.entryCoordinate, DiveMapCoordinateResolver.isUsable(entry) {
            rows.append(
                row(
                    "entryCoordinate",
                    "Entry GPS",
                    String(format: "%.5f°, %.5f°", entry.latitude, entry.longitude)
                )
            )
        }
        if let siteCoordinate = activity.siteCoordinate {
            rows.append(
                row(
                    "siteCoordinate",
                    "Site GPS",
                    String(format: "%.5f°, %.5f°", siteCoordinate.latitude, siteCoordinate.longitude)
                )
            )
        }
        return Section(id: "location", title: "Location", rows: rows)
    }

    private static func environmentSection(
        _ activity: DiveActivity,
        displayUnits: DiveDisplayUnitSystem
    ) -> Section {
        Section(
            id: "environment",
            title: "Water temperature",
            rows: [
                row("waterTempAvgCelsius", "Average", DiveQuantityFormatting.waterTemperature(celsius: activity.waterTempAvgCelsius, system: displayUnits)),
                row("waterTempMaxCelsius", "Maximum", DiveQuantityFormatting.waterTemperature(celsius: activity.waterTempMaxCelsius, system: displayUnits)),
                row("waterTempMinCelsius", "Minimum", DiveQuantityFormatting.waterTemperature(celsius: activity.waterTempMinCelsius, system: displayUnits)),
            ]
        )
    }

    private static func gasAndTankSection(
        _ activity: DiveActivity,
        displayUnits: DiveDisplayUnitSystem,
        defaultTank: DefaultTankSpecification
    ) -> Section {
        var rows: [Row] = [
            row("gasType", "Gas", activity.gasDetailsGasTypeLine),
            row("oxygenMix", "O₂ mix", activity.gasDetailsOxygenMixLine),
            row("tankMaterial", "Tank material", activity.gasDetailsTankTypeLine(defaultSpecification: defaultTank)),
            row(
                "tankVolumeDisplay",
                "Tank volume",
                activity.gasDetailsTankVolumeLine(displayUnits: displayUnits, defaultSpecification: defaultTank)
            ),
            row(
                "tankPressureStartPSI",
                "Beginning pressure",
                activity.gasDetailsBeginningPressureLine(displayUnits: displayUnits)
            ),
            row(
                "tankPressureEndPSI",
                "Ending pressure",
                activity.gasDetailsEndingPressureLine(displayUnits: displayUnits)
            ),
        ]
        if let stored = trimmed(activity.tankVolumeDescription) {
            rows.append(row("tankVolumeDescription", "Stored volume label", stored))
        }
        if let sac = activity.tankHeroSACRateLine(displayUnits: displayUnits) {
            rows.append(row("avgSAC", "SAC", sac))
        }
        if let rmv = activity.tankHeroRMVRateLine(displayUnits: displayUnits) {
            rows.append(row("avgRMV", "RMV", rmv))
        }
        return Section(id: "gas", title: "Gas & cylinder", rows: rows)
    }

    private static func userLogSection(_ activity: DiveActivity) -> Section {
        var rows: [Row] = []
        let current = activity.resolvedDiveCurrentStrength
        if current != .none {
            rows.append(row("diveCurrentStrength", "Current", current.displayTitle))
        }
        if let surface = trimmed(activity.surfaceCondition) {
            rows.append(row("surfaceCondition", "Surface conditions", surface))
        }
        if let entry = trimmed(activity.entryType) {
            rows.append(row("entryType", "Entry type", entry))
        }
        if let visibility = activity.diveVisibility {
            rows.append(row("diveVisibility", "Visibility", visibility.displayTitle))
        }
        if let operatorName = trimmed(activity.diveOperatorName) {
            rows.append(row("diveOperatorName", "Operator", operatorName))
        }
        if let master = trimmed(activity.diveMasterName) {
            rows.append(row("diveMasterName", "Divemaster", master))
        }
        if activity.diveSignatureData != nil {
            rows.append(row("diveSignatureData", "Signature", "On file"))
        }
        guard !rows.isEmpty else {
            return Section(id: "userLog", title: "Your log", rows: [])
        }
        return Section(id: "userLog", title: "Your log", rows: rows)
    }

    private static func buddiesSection(_ activity: DiveActivity) -> Section {
        let rows: [Row]
        if activity.buddies.isEmpty {
            rows = [row("buddies", "Buddies", "—")]
        } else {
            rows = activity.buddies.enumerated().map { index, buddy in
                row("buddy-\(buddy.id.uuidString)", "Buddy \(index + 1)", buddy.displayName)
            }
        }
        return Section(id: "buddies", title: "Buddies", rows: rows)
    }

    private static func equipmentSection(_ activity: DiveActivity) -> Section {
        let count = activity.equipmentItemIDs.count
        let value = count == 0 ? "—" : "\(count) item\(count == 1 ? "" : "s") (see Tank tab)"
        return Section(
            id: "equipment",
            title: "Equipment",
            rows: [row("equipmentList", "Linked gear", value)]
        )
    }

    private static func sourceSection(_ activity: DiveActivity) -> Section {
        var rows: [Row] = [
            row("deviceSource", "Device", activity.deviceSource.rawValue),
        ]
        if let sourceID = trimmed(activity.sourceDiveId) {
            rows.append(row("sourceDiveId", "Source dive ID", sourceID))
        }
        if let version = trimmed(activity.rawImportVersion) {
            rows.append(row("rawImportVersion", "Import / format", version))
        }
        return Section(id: "source", title: "Source & import", rows: rows)
    }

    private static func recordSection(_ activity: DiveActivity) -> Section {
        var rows: [Row] = [
            row("id", "Record ID", activity.id.uuidString),
        ]
        if let ownerName = trimmed(activity.owner?.displayName) {
            rows.append(row("owner", "Owner", ownerName))
        } else if let ownerID = activity.ownerProfileID {
            rows.append(row("ownerProfileID", "Owner profile ID", ownerID.uuidString))
        }
        return Section(id: "record", title: "Record", rows: rows)
    }

    // MARK: - Formatting

    private static func formatDateTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func formatDurationSeconds(_ seconds: Int?) -> String {
        guard let seconds, seconds > 0 else { return "—" }
        if seconds < 60 {
            return "\(seconds) s"
        }
        let minutes = seconds / 60
        let remainder = seconds % 60
        if remainder == 0 {
            return "\(minutes) min"
        }
        return "\(minutes) min \(remainder) s"
    }

    private static func formatAscentRate(metersPerSecond: Double, system: DiveDisplayUnitSystem) -> String {
        switch system {
        case .metric:
            return String(format: "%.2f m/s", metersPerSecond)
        case .imperial:
            let feetPerMinute = metersPerSecond * 3.280839895013123 * 60
            return String(format: "%.1f ft/min", feetPerMinute)
        }
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    private static func row(_ id: String, _ label: String, _ value: String) -> Row {
        Row(id: id, label: label, value: value)
    }
}
