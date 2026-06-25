import Foundation

/// Shared case-insensitive substring matching for catalog / list search fields.
enum CatalogSubstringSearch {

    nonisolated static func normalizedQuery(_ query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }

    nonisolated static func isFiltering(query: String) -> Bool {
        normalizedQuery(query) != nil
    }

    nonisolated static func matches(in haystack: String, query: String) -> Bool {
        guard let needle = normalizedQuery(query) else { return true }
        let normalized = haystack
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return false }
        return normalized.contains(needle)
    }

    nonisolated static func matchesAny(in haystacks: [String], query: String) -> Bool {
        guard isFiltering(query: query) else { return true }
        return haystacks.contains { matches(in: $0, query: query) }
    }

    /// Fast path when haystack text was pre-lowercased at index build time.
    nonisolated static func matchesPrelowercased(_ haystack: String, query: String) -> Bool {
        guard let needle = normalizedQuery(query) else { return true }
        guard !haystack.isEmpty else { return false }
        return haystack.contains(needle)
    }
}
