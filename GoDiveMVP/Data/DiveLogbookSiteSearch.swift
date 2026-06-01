import Foundation

/// Filters logbook dives by resolved site name and optional confirmed **`ActivityTag`**.
enum DiveLogbookSiteSearch {

    nonisolated static func normalizedQuery(_ query: String) -> String? {
        CatalogSubstringSearch.normalizedQuery(query)
    }

    nonisolated static func isFiltering(query: String) -> Bool {
        CatalogSubstringSearch.isFiltering(query: query)
    }

    /// Case-insensitive substring match on site title only.
    nonisolated static func matchesSite(resolvedSiteName: String?, query: String) -> Bool {
        CatalogSubstringSearch.matches(in: resolvedSiteName ?? "", query: query)
    }

    /// Whether a dive row has the confirmed tag (normalized name equality).
    nonisolated static func matchesConfirmedTag(
        activityTagNames: [String],
        confirmedTagName: String
    ) -> Bool {
        let target = ActivityTagStore.normalizedName(from: confirmedTagName)
        guard !target.isEmpty else { return false }
        return activityTagNames.contains {
            ActivityTagStore.normalizedName(from: $0) == target
        }
    }

    /// Whether a dive row tags the confirmed buddy (normalized display name equality).
    nonisolated static func matchesConfirmedBuddy(
        buddyDisplayNames: [String],
        confirmedBuddyName: String
    ) -> Bool {
        let target = DiveBuddyCatalog.normalizedNameKey(confirmedBuddyName)
        guard !target.isEmpty else { return false }
        return buddyDisplayNames.contains {
            DiveBuddyCatalog.normalizedNameKey($0) == target
        }
    }

    nonisolated static func filtering(
        _ seeds: [LogbookActivitySnapshotSeed],
        siteQuery: String,
        confirmedTagName: String? = nil,
        confirmedBuddyName: String? = nil
    ) -> [LogbookActivitySnapshotSeed] {
        if let confirmedTagName, !confirmedTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return seeds.filter {
                matchesConfirmedTag(
                    activityTagNames: $0.activityTagNames,
                    confirmedTagName: confirmedTagName
                )
            }
        }
        if let confirmedBuddyName, !confirmedBuddyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return seeds.filter {
                matchesConfirmedBuddy(
                    buddyDisplayNames: $0.buddyDisplayNames,
                    confirmedBuddyName: confirmedBuddyName
                )
            }
        }
        guard isFiltering(query: siteQuery) else { return seeds }
        return seeds.filter { $0.matchesSiteSearch(query: siteQuery) }
    }
}
