import Foundation

/// Stable, **`Equatable`** logbook row payload so SwiftUI can skip row bodies when only persisted **`diveNumber`** changes during background renumber.
struct DiveLogbookRowDisplayData: Equatable, Identifiable, Sendable {
    nonisolated private static let defaultScubaLeadingSymbolName = LogbookActivityRowPresentation.scubaDiveLeadingSymbolName

    let id: UUID
    let activityKind: LogbookActivitySnapshotKind
    let displayName: String
    let diveNumberLabel: String
    let diveNumberLeadingSymbolName: String?
    let detailLine: String
    let showsDuplicateHint: Bool
    let previewMediaPhotoID: UUID?
    let previewMediaIsSnorkel: Bool
    let startTime: Date

    nonisolated init(
        id: UUID,
        activityKind: LogbookActivitySnapshotKind = .scubaDive,
        displayName: String,
        diveNumberLabel: String,
        diveNumberLeadingSymbolName: String? = defaultScubaLeadingSymbolName,
        detailLine: String,
        showsDuplicateHint: Bool,
        previewMediaPhotoID: UUID?,
        previewMediaIsSnorkel: Bool = false,
        startTime: Date
    ) {
        self.id = id
        self.activityKind = activityKind
        self.displayName = displayName
        self.diveNumberLabel = diveNumberLabel
        self.diveNumberLeadingSymbolName = diveNumberLeadingSymbolName
        self.detailLine = detailLine
        self.showsDuplicateHint = showsDuplicateHint
        self.previewMediaPhotoID = previewMediaPhotoID
        self.previewMediaIsSnorkel = previewMediaIsSnorkel
        self.startTime = startTime
    }

    /// Explicit **`nonisolated`** equality for Swift 6 checks from nonisolated contexts.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.activityKind == rhs.activityKind
            && lhs.displayName == rhs.displayName
            && lhs.diveNumberLabel == rhs.diveNumberLabel
            && lhs.diveNumberLeadingSymbolName == rhs.diveNumberLeadingSymbolName
            && lhs.detailLine == rhs.detailLine
            && lhs.showsDuplicateHint == rhs.showsDuplicateHint
            && lhs.previewMediaPhotoID == rhs.previewMediaPhotoID
            && lhs.previewMediaIsSnorkel == rhs.previewMediaIsSnorkel
            && lhs.startTime == rhs.startTime
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
        numberingActivities: [DiveActivity]? = nil,
        numberingRows: [DiveActivityDiveNumbering.NumberingRow]? = nil
    ) -> [DiveLogbookRowDisplayData] {
        let chronologicalNumbers: [UUID: Int] = useChronologicalNumbers
            ? {
                if let numberingRows {
                    return DiveActivityDiveNumbering.numberedDiveSequentialIndicesById(for: numberingRows)
                }
                let numberingSource = numberingActivities ?? activities
                return DiveActivityDiveNumbering.numberedDiveSequentialIndicesById(for: numberingSource)
            }()
            : [:]

        return activities.map { activity in
            DiveLogbookRowDisplayData(
                id: activity.id,
                activityKind: .scubaDive,
                displayName: LogbookActivityRow.displayName(for: activity),
                diveNumberLabel: logbookDiveNumberLabel(
                    for: activity,
                    chronologicalNumbers: chronologicalNumbers,
                    useChronologicalNumbers: useChronologicalNumbers
                ),
                diveNumberLeadingSymbolName: LogbookActivityRowPresentation.scubaDiveLeadingSymbolName,
                detailLine: detailLine(for: activity, unitSystem: unitSystem),
                showsDuplicateHint: duplicateIds.contains(activity.id),
                previewMediaPhotoID: DiveActivityMediaPresentation.featuredPhotoID(on: activity),
                startTime: activity.startTime
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

    /// Search / list rows for snorkel activities — same payload shape as scuba **`rowData`**.
    nonisolated static func snorkelRowData(
        from seeds: [LogbookActivitySnapshotSeed],
        unitSystem: DiveDisplayUnitSystem
    ) -> [DiveLogbookRowDisplayData] {
        seeds.filter { $0.kind == .snorkel }.map { seed in
            DiveLogbookRowDisplayData(
                id: seed.id,
                activityKind: .snorkel,
                displayName: seed.displayName,
                diveNumberLabel: LogbookActivityRowPresentation.snorkelChipTitle,
                diveNumberLeadingSymbolName: LogbookActivityRowPresentation.snorkelLeadingSymbolName,
                detailLine: snorkelDetailLine(for: seed, unitSystem: unitSystem),
                showsDuplicateHint: false,
                previewMediaPhotoID: seed.previewMediaPhotoID,
                previewMediaIsSnorkel: true,
                startTime: seed.startTime
            )
        }
    }

    nonisolated private static func snorkelDetailLine(
        for seed: LogbookActivitySnapshotSeed,
        unitSystem: DiveDisplayUnitSystem
    ) -> String {
        var parts = [seed.formattedStartDateOnly]
        if let meters = seed.swimDistanceMeters, meters > 0 {
            parts.append(DiveQuantityFormatting.swimDistance(meters: meters, system: unitSystem))
        }
        if seed.maxDepthMeters > 0 {
            parts.append(DiveQuantityFormatting.depth(meters: seed.maxDepthMeters, system: unitSystem))
        }
        parts.append("\(seed.durationMinutes) min")
        return parts.joined(separator: " · ")
    }
}

/// Equality inputs for **`LogbookListSurface`** (**.equatable()**).
struct LogbookListSurfaceEquatableInputs: Equatable, Sendable {
    var feedScope: LogbookFeedScope
    var myActivitiesKindFilter: LogbookMyActivitiesKindFilter
    var showsMyActivitiesKindFilterEmptyState: Bool
    var items: [LogbookListDisplayItem]
    var buddyFeedRows: [LogbookBuddyFeedPresentation.Row]
    var buddyFeedHasMoreRows: Bool
    var buddyFeedTotalRowCount: Int
    var buddyFeedEmptyKind: LogbookBuddyFeedPresentation.EmptyKind?
    var isBuddyFeedLoading: Bool
    var isMyActivitiesLoading: Bool
    var upcomingTripBanner: LogbookUpcomingTripBannerData?
    var showsStoredDiveEmptyState: Bool
    var bubbleAnimationPaused: Bool
    var scrollToTopNonce: Int

    /// Explicit **`nonisolated`** equality — avoids MainActor-isolated synthesis when compared from **`LogbookListSurface`** and unit tests.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.feedScope == rhs.feedScope
            && lhs.myActivitiesKindFilter == rhs.myActivitiesKindFilter
            && lhs.showsMyActivitiesKindFilterEmptyState == rhs.showsMyActivitiesKindFilterEmptyState
            && lhs.items == rhs.items
            && LogbookBuddyFeedPresentation.rowsEqual(lhs.buddyFeedRows, rhs.buddyFeedRows)
            && lhs.buddyFeedHasMoreRows == rhs.buddyFeedHasMoreRows
            && lhs.buddyFeedTotalRowCount == rhs.buddyFeedTotalRowCount
            && LogbookBuddyFeedPresentation.emptyKindsEqual(lhs.buddyFeedEmptyKind, rhs.buddyFeedEmptyKind)
            && lhs.isBuddyFeedLoading == rhs.isBuddyFeedLoading
            && lhs.isMyActivitiesLoading == rhs.isMyActivitiesLoading
            && lhs.upcomingTripBanner == rhs.upcomingTripBanner
            && lhs.showsStoredDiveEmptyState == rhs.showsStoredDiveEmptyState
            && lhs.bubbleAnimationPaused == rhs.bubbleAnimationPaused
            && lhs.scrollToTopNonce == rhs.scrollToTopNonce
    }
}
