import Foundation

/// Filters logbook dives by **`DiveActivity.resolvedSiteName`** (linked catalog name or import **`siteName`**).
enum DiveLogbookSiteSearch {

    /// **`nil`** when the query is empty or whitespace-only (show all dives).
    static func normalizedQuery(_ query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }

    static func isFiltering(query: String) -> Bool {
        normalizedQuery(query) != nil
    }

    static func matches(activity: DiveActivity, query: String) -> Bool {
        guard let needle = normalizedQuery(query) else { return true }
        guard let siteName = activity.resolvedSiteName?.lowercased() else { return false }
        return siteName.contains(needle)
    }

    static func filtering(_ activities: [DiveActivity], query: String) -> [DiveActivity] {
        guard isFiltering(query: query) else { return activities }
        return activities.filter { matches(activity: $0, query: query) }
    }
}
