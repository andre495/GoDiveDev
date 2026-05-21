import Foundation

/// Stable, **`Equatable`** logbook row payload so SwiftUI can skip row bodies when only persisted **`diveNumber`** changes during background renumber.
struct DiveLogbookRowDisplayData: Equatable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let diveNumberLabel: String
    let detailLine: String
    let showsDuplicateHint: Bool
}

/// Builds logbook row display values (including **#** labels).
enum DiveLogbookDisplay {

    /// When **`useChronologicalNumbers`** is **`true`** (Settings → automatic renumber), **#** comes from **`startTime`** order in **`numberingActivities`** (full logbook), not the filtered **`activities`** rows — site search only hides rows; it does not renumber them.
    static func rowData(
        activities: [DiveActivity],
        unitSystem: DiveDisplayUnitSystem,
        duplicateIds: Set<UUID>,
        useChronologicalNumbers: Bool,
        numberingActivities: [DiveActivity]? = nil
    ) -> [DiveLogbookRowDisplayData] {
        let numberingSource = numberingActivities ?? activities
        let chronologicalNumbers: [UUID: Int] = useChronologicalNumbers
            ? DiveActivityDiveNumbering.numberedDiveSequentialIndicesById(for: numberingSource)
            : [:]

        return activities.map { activity in
            DiveLogbookRowDisplayData(
                id: activity.id,
                displayName: LogbookActivityRow.displayName(for: activity),
                diveNumberLabel: logbookDiveNumberLabel(
                    for: activity,
                    chronologicalNumbers: chronologicalNumbers,
                    useChronologicalNumbers: useChronologicalNumbers
                ),
                detailLine: detailLine(for: activity, unitSystem: unitSystem),
                showsDuplicateHint: duplicateIds.contains(activity.id)
            )
        }
    }

    private static func logbookDiveNumberLabel(
        for activity: DiveActivity,
        chronologicalNumbers: [UUID: Int],
        useChronologicalNumbers: Bool
    ) -> String {
        if activity.diveNumberExplicitlyNone {
            return "-"
        }
        if useChronologicalNumbers, let n = chronologicalNumbers[activity.id] {
            return "#\(n)"
        }
        return activity.diveNumberLogbookLabel
    }

    private static func detailLine(for activity: DiveActivity, unitSystem: DiveDisplayUnitSystem) -> String {
        let dateStr = activity.startTime.formatted(date: .abbreviated, time: .omitted)
        let depth = DiveQuantityFormatting.depth(meters: activity.maxDepthMeters, system: unitSystem)
        let dur = "\(activity.durationMinutes) min"
        return "\(dateStr) · \(depth) · \(dur)"
    }
}
