import Foundation

/// Dive count + total in-water time for the logbook **My Activities** list header.
struct LogbookMyActivitiesSummary: Sendable, Equatable {
    let diveCount: Int
    let totalBottomTimeSeconds: Int

    static let empty = LogbookMyActivitiesSummary(diveCount: 0, totalBottomTimeSeconds: 0)

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.diveCount == rhs.diveCount
            && lhs.totalBottomTimeSeconds == rhs.totalBottomTimeSeconds
    }
}

enum LogbookMyActivitiesSummaryPresentation: Sendable {

    nonisolated static func summary(from seeds: [LogbookActivitySnapshotSeed]) -> LogbookMyActivitiesSummary {
        let diveSeeds = seeds.filter { $0.kind == .scubaDive }
        let numberedRows = diveSeeds.map(\.numberingRow)
        let totalSeconds = diveSeeds.reduce(0) { partial, seed in
            partial + DiveActivityDuplicateMatcher.effectiveInWaterSeconds(seed.duplicateSignature)
        }
        return LogbookMyActivitiesSummary(
            diveCount: DiveActivityDiveNumbering.numberedDiveCount(in: numberedRows),
            totalBottomTimeSeconds: max(0, totalSeconds)
        )
    }

    /// Centered list chrome, e.g. **`12 Dives | 4 hr Bottom Time`** (hours only, nearest hour).
    nonisolated static func headerLine(for summary: LogbookMyActivitiesSummary) -> String {
        let diveWord = summary.diveCount == 1 ? "Dive" : "Dives"
        let duration = formattedBottomTimeHoursRounded(totalBottomTimeSeconds: summary.totalBottomTimeSeconds)
        return "\(summary.diveCount) \(diveWord) | \(duration) Bottom Time"
    }

    /// Rounds total in-water time to the nearest whole hour — **no minutes** in summary chrome.
    nonisolated static func formattedBottomTimeHoursRounded(totalBottomTimeSeconds: Int) -> String {
        let hours = Int((Double(max(0, totalBottomTimeSeconds)) / 3600.0).rounded())
        return hours == 1 ? "1 hr" : "\(hours) hr"
    }

    nonisolated static let loadingAccessibilityIdentifier = "Logbook.MyActivitiesLoading"

    /// Dives are in SwiftData but the off-main row cache has not painted yet — avoid flashing **0 Dives | 0 Bottom Time**.
    nonisolated static func showsLoadingChrome(
        feedScope: LogbookFeedScope,
        visibleDiveCount: Int,
        visibleSnorkelCount: Int,
        kindFilter: LogbookMyActivitiesKindFilter,
        displayItemCount: Int
    ) -> Bool {
        guard feedScope == .myActivities else { return false }
        let expectedCount = LogbookMyActivitiesKindFilterPresentation.matchingStoredActivityCount(
            diveCount: visibleDiveCount,
            snorkelCount: visibleSnorkelCount,
            filter: kindFilter
        )
        guard expectedCount > 0 else { return false }
        return displayItemCount == 0
    }
}
