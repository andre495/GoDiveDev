import Foundation

/// User-facing copy and formatting for **`DiveTrip`** screens.
enum DiveTripPresentation: Sendable {
    nonisolated static let detailPageTitle = "Trip details"
    nonisolated static let plannedSitesSectionTitle = "Planned dive sites"
    nonisolated static let countriesSectionTitle = "Countries"
    nonisolated static let datesSectionTitle = "Dates"
    nonisolated static let invalidDateRangeMessage = "Start date must be on or before the end date."
    nonisolated static let linkedDivesSectionTitle = "View Activities"
    nonisolated static let linkedDivesEmptyMessage =
        "Link logbook dives after your trip to see them here."
    nonisolated static let tripMediaSectionTitle = "Trip media"
    nonisolated static let tripMediaEmptyMessage =
        "Photos and videos from linked dives will appear here."
    nonisolated static let tripMediaOpenOnDiveButtonTitle = "View Dive"
    nonisolated static let tripMarineLifeSectionTitle = "Marine life"
    nonisolated static let tripMarineLifeEmptyMessage =
        "Species tagged on linked dives will appear here."
    nonisolated static let tripBuddiesSectionTitle = "Dive buddies"
    nonisolated static let tripBuddiesEmptyMessage =
        "Buddies tagged on linked dives will appear here."
    nonisolated static let tripBuddiesPlannedEmptyMessage =
        "Add buddies you're diving with on this trip."
    nonisolated static let tripPlannedSitesEmptyMessage =
        "Add dive sites when editing this trip."
    nonisolated static let addPlannedBuddyButtonTitle = "Add buddy"
    nonisolated static let addPlannedBuddyAccessibilityLabel = "Add buddy to trip"
    nonisolated static let addPlannedSiteAccessibilityLabel = "Add or remove saved dive sites"
    nonisolated static let shareTripButtonTitle = "Share"
    nonisolated static let tripPlannedBuddyPickerTitle = "Trip buddies"
    nonisolated static let tripPlannedBuddyPickerFooter = "Tap a buddy to add or remove them from this trip."
    nonisolated static let tripPlannedBuddyPickerEmptyRosterMessage =
        "No buddies in your roster yet. Tap + to add someone to your roster, then add them to this trip."

    nonisolated static func tripBuddyTaggedDiveCountLabel(count: Int) -> String {
        switch count {
        case 0:
            return "Not tagged on any dives"
        case 1:
            return "1 dive"
        default:
            return "\(count) dives"
        }
    }

    /// Linked logbook dives, newest **`startTime`** first.
    static func linkedDiveActivities(for trip: DiveTrip) -> [DiveActivity] {
        trip.linkedActivities.sorted { lhs, rhs in
            if lhs.startTime != rhs.startTime { return lhs.startTime > rhs.startTime }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Inputs for refreshing cached logbook rows on trip detail.
    struct LinkedDiveListRefreshToken: Equatable, Sendable {
        let tripID: UUID
        let linkedDiveIDs: [UUID]
        let unitSystem: DiveDisplayUnitSystem
        let useChronologicalNumbers: Bool
        let numberingActivityCount: Int
    }

    static func linkedDiveListRefreshToken(
        trip: DiveTrip,
        unitSystem: DiveDisplayUnitSystem,
        useChronologicalNumbers: Bool,
        numberingActivities: [DiveActivity]
    ) -> LinkedDiveListRefreshToken {
        let linked = linkedDiveActivities(for: trip)
        return LinkedDiveListRefreshToken(
            tripID: trip.id,
            linkedDiveIDs: linked.map(\.id),
            unitSystem: unitSystem,
            useChronologicalNumbers: useChronologicalNumbers,
            numberingActivityCount: numberingActivities.count
        )
    }

    static func linkedDiveRowDisplayData(
        trip: DiveTrip,
        unitSystem: DiveDisplayUnitSystem,
        useChronologicalNumbers: Bool,
        numberingActivities: [DiveActivity]
    ) -> [DiveLogbookRowDisplayData] {
        DiveLogbookDisplay.rowData(
            activities: linkedDiveActivities(for: trip),
            unitSystem: unitSystem,
            duplicateIds: [],
            useChronologicalNumbers: useChronologicalNumbers,
            numberingActivities: numberingActivities
        )
    }

    nonisolated static func linkedDivesSummary(totalDurationMinutes: Int) -> String {
        "\(totalDurationMinutes) total minutes underwater"
    }

    nonisolated static func formattedDateRange(start: Date, end: Date) -> String {
        let normalized = DiveTripDateRange.normalizedRange(start: start, end: end)
        let startText = normalized.start.formatted(date: .abbreviated, time: .omitted)
        let endText = normalized.end.formatted(date: .abbreviated, time: .omitted)
        if startText == endText { return startText }
        return "\(startText) – \(endText)"
    }

    nonisolated static func plannedSitesSummary(selectedCount: Int) -> String {
        switch selectedCount {
        case 0:
            return "None selected"
        case 1:
            return "1 site selected"
        default:
            return "\(selectedCount) sites selected"
        }
    }

    nonisolated static func plannedSitesOverviewSummary(siteCount: Int) -> String {
        switch siteCount {
        case 0:
            return "None planned"
        case 1:
            return "1 site"
        default:
            return "\(siteCount) sites"
        }
    }

    /// Subtitle on the planned-trip **Planned dive sites** pager page when sites exist.
    nonisolated static let plannedSitesPageSavedSitesSubtitle = "Saved Dive Sites"

    /// Subtitle on the planned-trip **Planned dive sites** pager page.
    nonisolated static func plannedSitesPageSubtitle(siteCount: Int) -> String {
        guard siteCount > 0 else { return tripPlannedSitesEmptyMessage }
        return plannedSitesPageSavedSitesSubtitle
    }
}
