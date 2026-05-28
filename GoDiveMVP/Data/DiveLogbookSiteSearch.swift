import Foundation

/// Filters logbook dives by resolved site name (linked catalog name or import **`siteName`**).
enum DiveLogbookSiteSearch {

    nonisolated static func normalizedQuery(_ query: String) -> String? {
        CatalogSubstringSearch.normalizedQuery(query)
    }

    nonisolated static func isFiltering(query: String) -> Bool {
        CatalogSubstringSearch.isFiltering(query: query)
    }

    /// Case-insensitive substring match on a resolved site title (testable without **`DiveActivity`**).
    nonisolated static func matches(resolvedSiteName: String?, query: String) -> Bool {
        CatalogSubstringSearch.matchesAny(in: [resolvedSiteName ?? ""], query: query)
    }

    nonisolated static func filtering(
        _ seeds: [LogbookActivitySnapshotSeed],
        query: String
    ) -> [LogbookActivitySnapshotSeed] {
        guard isFiltering(query: query) else { return seeds }
        return seeds.filter { $0.matchesSiteSearch(query: query) }
    }
}
