import Foundation

/// My Activities list kind filter — does not apply to Buddy Feed.
enum LogbookMyActivitiesKindFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case dives
    case snorkels

    var id: String { rawValue }
}

enum LogbookMyActivitiesKindFilterPresentation: Sendable {
    nonisolated static let menuAccessibilityIdentifier = "Logbook.MyActivitiesKindFilter.Menu"
    nonisolated static let filterButtonAccessibilityIdentifier = "Logbook.MyActivitiesKindFilter.Button"

    nonisolated static func menuTitle(for filter: LogbookMyActivitiesKindFilter) -> String {
        switch filter {
        case .all:
            "All activities"
        case .dives:
            "Dives"
        case .snorkels:
            "Snorkels"
        }
    }

    nonisolated static func filterButtonAccessibilityLabel(filter: LogbookMyActivitiesKindFilter) -> String {
        switch filter {
        case .all:
            "Filter activities, showing all"
        case .dives:
            "Filter activities, showing dives only"
        case .snorkels:
            "Filter activities, showing snorkels only"
        }
    }

    nonisolated static func emptyStateTitle(filter: LogbookMyActivitiesKindFilter) -> String {
        switch filter {
        case .all:
            "No activities"
        case .dives:
            "No dives"
        case .snorkels:
            "No snorkels"
        }
    }

    nonisolated static func emptyStateMessage(filter: LogbookMyActivitiesKindFilter) -> String {
        switch filter {
        case .all:
            "Import or log an activity to see it here."
        case .dives:
            "Try All activities or add a dive."
        case .snorkels:
            "Try All activities or add a snorkel."
        }
    }

    nonisolated static func matchingStoredActivityCount(
        diveCount: Int,
        snorkelCount: Int,
        filter: LogbookMyActivitiesKindFilter
    ) -> Int {
        switch filter {
        case .all:
            diveCount + snorkelCount
        case .dives:
            diveCount
        case .snorkels:
            snorkelCount
        }
    }

    nonisolated static func filteredSeeds(
        _ seeds: [LogbookActivitySnapshotSeed],
        filter: LogbookMyActivitiesKindFilter
    ) -> [LogbookActivitySnapshotSeed] {
        switch filter {
        case .all:
            seeds
        case .dives:
            seeds.filter { $0.kind == .scubaDive }
        case .snorkels:
            seeds.filter { $0.kind == .snorkel }
        }
    }
}
