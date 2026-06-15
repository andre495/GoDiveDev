import Foundation

/// Tag search suggestion under the logbook search field (**tag: …**).
struct LogbookTagSearchSuggestion: Identifiable, Equatable, Sendable {
    let id: String
    let tagName: String

    var promptLine: String {
        "tag: \(tagName)"
    }
}

/// Logbook search: free-text site filter vs an explicit confirmed tag filter.
enum LogbookTagSearchPresentation {

    struct Filter: Equatable, Sendable {
        var siteQuery: String
        var confirmedTagName: String?

        nonisolated var isActive: Bool {
            DiveLogbookSiteSearch.isFiltering(query: siteQuery) || confirmedTagName != nil
        }
    }

    nonisolated static func suggestions(
        catalogTagNames: [String],
        query: String,
        activeTagFilter: String?,
        activeBuddyFilter: String? = nil,
        activeTripFilter: LogbookTripSearchSuggestion? = nil
    ) -> [LogbookTagSearchSuggestion] {
        guard activeTagFilter == nil,
              activeBuddyFilter == nil,
              activeTripFilter == nil,
              DiveLogbookSiteSearch.isFiltering(query: query)
        else { return [] }

        var seenNormalized = Set<String>()
        var suggestions: [LogbookTagSearchSuggestion] = []

        for name in catalogTagNames {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard CatalogSubstringSearch.matches(in: trimmed, query: query) else { continue }

            let normalized = ActivityTagStore.normalizedName(from: trimmed)
            guard !normalized.isEmpty, seenNormalized.insert(normalized).inserted else { continue }

            suggestions.append(
                LogbookTagSearchSuggestion(id: normalized, tagName: trimmed)
            )
        }

        return suggestions.sorted {
            $0.tagName.localizedCaseInsensitiveCompare($1.tagName) == .orderedAscending
        }
    }

    nonisolated static func activeTagPromptLine(tagName: String) -> String {
        "tag: \(tagName)"
    }
}
