import Foundation

/// Buddy search suggestion under the logbook search field (**buddy: …**).
struct LogbookBuddySearchSuggestion: Identifiable, Equatable, Sendable {
    let id: String
    let buddyName: String

    var promptLine: String {
        "buddy: \(buddyName)"
    }
}

/// Logbook search: buddy roster suggestions and confirmed buddy filter.
enum LogbookBuddySearchPresentation {

    nonisolated static func suggestions(
        catalogBuddyNames: [String],
        query: String,
        activeBuddyFilter: String?,
        activeTagFilter: String?
    ) -> [LogbookBuddySearchSuggestion] {
        guard activeBuddyFilter == nil,
              activeTagFilter == nil,
              DiveLogbookSiteSearch.isFiltering(query: query)
        else { return [] }

        var seenNormalized = Set<String>()
        var suggestions: [LogbookBuddySearchSuggestion] = []

        for name in catalogBuddyNames {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard CatalogSubstringSearch.matches(in: trimmed, query: query) else { continue }

            let normalized = DiveBuddyCatalog.normalizedNameKey(trimmed)
            guard !normalized.isEmpty, seenNormalized.insert(normalized).inserted else { continue }

            suggestions.append(
                LogbookBuddySearchSuggestion(id: normalized, buddyName: trimmed)
            )
        }

        return suggestions.sorted {
            $0.buddyName.localizedCaseInsensitiveCompare($1.buddyName) == .orderedAscending
        }
    }

    nonisolated static func activeBuddyPromptLine(buddyName: String) -> String {
        "buddy: \(buddyName)"
    }
}
