import Foundation

/// Filters Explore dive-site list rows by name and place hierarchy.
enum ExploreDiveSiteListSearch {

    nonisolated static func isFiltering(query: String) -> Bool {
        CatalogSubstringSearch.isFiltering(query: query)
    }

    nonisolated static func matches(_ site: DiveSite, query: String) -> Bool {
        CatalogSubstringSearch.matchesAny(
            in: [
                site.siteName,
                ExploreDiveSiteListDisplay.placeSummary(
                    country: site.country,
                    region: site.region,
                    bodyOfWater: site.bodyOfWater
                ),
                site.country,
                site.region,
                site.bodyOfWater,
            ],
            query: query
        )
    }

    nonisolated static func filtering(_ sites: [DiveSite], query: String) -> [DiveSite] {
        guard isFiltering(query: query) else { return sites }
        return sites.filter { matches($0, query: query) }
    }
}
