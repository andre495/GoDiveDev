import Foundation

/// Trip search suggestion under the logbook search field (**trip: …**).
struct LogbookTripSearchSuggestion: Identifiable, Equatable, Sendable {
    let id: String
    let tripID: UUID
    let displayTitle: String

    var promptLine: String {
        "trip: \(displayTitle)"
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.tripID == rhs.tripID
            && lhs.displayTitle == rhs.displayTitle
    }
}

/// Owner trip row for logbook search suggestions (Sendable catalog entry).
struct LogbookTripSearchCatalogEntry: Equatable, Sendable {
    let tripID: UUID
    let displayTitle: String
}

/// Logbook search: trip roster suggestions and confirmed trip filter.
enum LogbookTripSearchPresentation {

    nonisolated static func suggestions(
        catalogTrips: [LogbookTripSearchCatalogEntry],
        query: String,
        activeTripFilter: LogbookTripSearchSuggestion?,
        activeTagFilter: String?,
        activeBuddyFilter: String?
    ) -> [LogbookTripSearchSuggestion] {
        guard activeTripFilter == nil,
              activeTagFilter == nil,
              activeBuddyFilter == nil,
              DiveLogbookSiteSearch.isFiltering(query: query)
        else { return [] }

        var seenTripIDs = Set<UUID>()
        var suggestions: [LogbookTripSearchSuggestion] = []

        for entry in catalogTrips {
            let trimmed = entry.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard CatalogSubstringSearch.matches(in: trimmed, query: query) else { continue }
            guard seenTripIDs.insert(entry.tripID).inserted else { continue }

            suggestions.append(
                LogbookTripSearchSuggestion(
                    id: entry.tripID.uuidString,
                    tripID: entry.tripID,
                    displayTitle: trimmed
                )
            )
        }

        return suggestions.sorted {
            $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }
    }

    nonisolated static func activeTripPromptLine(displayTitle: String) -> String {
        "trip: \(displayTitle)"
    }
}
