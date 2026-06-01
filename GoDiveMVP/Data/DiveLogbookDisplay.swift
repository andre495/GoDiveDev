import Foundation

/// Stable, **`Equatable`** logbook row payload so SwiftUI can skip row bodies when only persisted **`diveNumber`** changes during background renumber.
struct DiveLogbookRowDisplayData: Equatable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let diveNumberLabel: String
    let detailLine: String
    let showsDuplicateHint: Bool
    /// Featured media (user-chosen, else oldest gallery item — **`DiveActivityMediaPresentation.featuredPhotoID`**); **`nil`** when the dive has no media.
    let previewMediaPhotoID: UUID?

    /// Explicit **`nonisolated`** equality for Swift 6 checks from nonisolated contexts.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.displayName == rhs.displayName
            && lhs.diveNumberLabel == rhs.diveNumberLabel
            && lhs.detailLine == rhs.detailLine
            && lhs.showsDuplicateHint == rhs.showsDuplicateHint
            && lhs.previewMediaPhotoID == rhs.previewMediaPhotoID
    }
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
                showsDuplicateHint: duplicateIds.contains(activity.id),
                previewMediaPhotoID: DiveActivityMediaPresentation.featuredPhotoID(on: activity)
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
        let dateStr = activity.formattedStartDateOnly()
        let depth = DiveQuantityFormatting.depth(meters: activity.maxDepthMeters, system: unitSystem)
        let dur = "\(activity.durationMinutes) min"
        return "\(dateStr) · \(depth) · \(dur)"
    }
}

/// Equality inputs for **`LogbookListSurface`** (**.equatable()**). Includes search focus so top chrome can swap **+** / **Cancel** without rebuilding the list on every SwiftData merge.
struct LogbookListSurfaceEquatableInputs: Equatable, Sendable {
    var rows: [DiveLogbookRowDisplayData]
    var showsStoredDiveEmptyState: Bool
    var isFilteringBySiteName: Bool
    var siteSearchQuery: String
    var activeTagFilter: String?
    var activeBuddyFilter: String?
    var tagSuggestionSignature: String
    var buddySuggestionSignature: String
    var isSiteSearchFocused: Bool
    var bubbleAnimationPaused: Bool
    var headerClearance: CGFloat
    var scrollToTopNonce: Int

    /// Explicit **`nonisolated`** equality — avoids MainActor-isolated synthesis when compared from **`LogbookListSurface`** and unit tests.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rows == rhs.rows
            && lhs.showsStoredDiveEmptyState == rhs.showsStoredDiveEmptyState
            && lhs.isFilteringBySiteName == rhs.isFilteringBySiteName
            && lhs.siteSearchQuery == rhs.siteSearchQuery
            && lhs.activeTagFilter == rhs.activeTagFilter
            && lhs.activeBuddyFilter == rhs.activeBuddyFilter
            && lhs.tagSuggestionSignature == rhs.tagSuggestionSignature
            && lhs.buddySuggestionSignature == rhs.buddySuggestionSignature
            && lhs.isSiteSearchFocused == rhs.isSiteSearchFocused
            && lhs.bubbleAnimationPaused == rhs.bubbleAnimationPaused
            && lhs.headerClearance == rhs.headerClearance
            && lhs.scrollToTopNonce == rhs.scrollToTopNonce
    }
}
