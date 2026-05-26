import Foundation

/// Filters logbook dives by resolved site name (linked catalog name or import **`siteName`**).
enum DiveLogbookSiteSearch {

    nonisolated static func normalizedQuery(_ query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }

    nonisolated static func isFiltering(query: String) -> Bool {
        normalizedQuery(query) != nil
    }

    /// Case-insensitive substring match on a resolved site title (testable without **`DiveActivity`**).
    nonisolated static func matches(resolvedSiteName: String?, query: String) -> Bool {
        guard let needle = normalizedQuery(query) else { return true }
        let siteName = resolvedSiteName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard !siteName.isEmpty else { return false }
        return siteName.contains(needle)
    }

    nonisolated static func filtering(
        _ seeds: [LogbookActivitySnapshotSeed],
        query: String
    ) -> [LogbookActivitySnapshotSeed] {
        guard isFiltering(query: query) else { return seeds }
        return seeds.filter { $0.matchesSiteSearch(query: query) }
    }
}
