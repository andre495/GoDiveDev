import Foundation

struct DiveTripStatTile: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let value: String
    let footnote: String
    let systemImage: String
    /// When set, the tile opens the linked dive activity (deepest / longest).
    let linkedDiveID: UUID?

    nonisolated init(
        id: String,
        title: String,
        value: String,
        footnote: String,
        systemImage: String,
        linkedDiveID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.footnote = footnote
        self.systemImage = systemImage
        self.linkedDiveID = linkedDiveID
    }
}

/// Highlight stats for **`TripDetailView`** once a trip is underway or complete.
enum DiveTripStatsPresentation: Sendable {

    nonisolated static let sectionTitle = "Trip stats"
    nonisolated static let emptyValue = "—"
    nonisolated static let highlightTileCount = 4

    nonisolated static let diveCountFootnoteSingular = "activity"
    nonisolated static let diveCountFootnotePlural = "activities"
    nonisolated static let totalBottomTimeFootnote = "total bottom time"
    nonisolated static let maxDepthFootnote = "max depth"
    nonisolated static let bottomTimeFootnote = "bottom time"

    /// **`true`** when the trip start calendar day is on or before **`referenceDate`**.
    nonisolated static func shouldShowStats(
        tripStartDate: Date,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        let startDay = calendar.startOfDay(for: tripStartDate)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        return startDay <= referenceDay
    }

    nonisolated static func highlightTiles(
        from aggregate: DiveTripAggregate,
        unitSystem: DiveDisplayUnitSystem
    ) -> [DiveTripStatTile] {
        [
            diveCountTile(count: aggregate.diveCount),
            totalTimeTile(minutes: aggregate.totalDurationMinutes),
            deepestTile(deepest: aggregate.deepestDive, unitSystem: unitSystem),
            longestTile(longest: aggregate.longestDive),
        ]
    }

    // MARK: - Tiles

    private nonisolated static func diveCountTile(count: Int) -> DiveTripStatTile {
        DiveTripStatTile(
            id: "dives",
            title: "Dives",
            value: "\(count)",
            footnote: count == 1 ? diveCountFootnoteSingular : diveCountFootnotePlural,
            systemImage: "list.bullet.rectangle.fill"
        )
    }

    private nonisolated static func totalTimeTile(minutes: Int) -> DiveTripStatTile {
        let value = minutes > 0
            ? HomeLifetimeStatsPresentation.formattedDuration(minutes: minutes)
            : emptyValue
        let footnote = minutes > 0 ? totalBottomTimeFootnote : "Link dives to track time"
        return DiveTripStatTile(
            id: "underwater-time",
            title: "Underwater",
            value: value,
            footnote: footnote,
            systemImage: "timer"
        )
    }

    private nonisolated static func deepestTile(
        deepest: DiveTripDeepestDiveSummary?,
        unitSystem: DiveDisplayUnitSystem
    ) -> DiveTripStatTile {
        let value: String
        let footnote: String
        if let deepest, deepest.maxDepthMeters > 0 {
            value = DiveQuantityFormatting.depth(meters: deepest.maxDepthMeters, system: unitSystem)
            footnote = maxDepthFootnote
        } else {
            value = emptyValue
            footnote = "No depth logged yet"
        }
        return DiveTripStatTile(
            id: "deepest",
            title: "Deepest",
            value: value,
            footnote: footnote,
            systemImage: "arrow.down.to.line.compact",
            linkedDiveID: (deepest?.maxDepthMeters ?? 0) > 0 ? deepest?.diveID : nil
        )
    }

    private nonisolated static func longestTile(longest: DiveTripLongestDiveSummary?) -> DiveTripStatTile {
        let value: String
        let footnote: String
        if let longest, longest.durationMinutes > 0 {
            value = HomeLifetimeStatsPresentation.formattedDuration(minutes: longest.durationMinutes)
            footnote = bottomTimeFootnote
        } else {
            value = emptyValue
            footnote = "No bottom time yet"
        }
        return DiveTripStatTile(
            id: "longest",
            title: "Longest",
            value: value,
            footnote: footnote,
            systemImage: "clock.fill",
            linkedDiveID: (longest?.durationMinutes ?? 0) > 0 ? longest?.diveID : nil
        )
    }
}
