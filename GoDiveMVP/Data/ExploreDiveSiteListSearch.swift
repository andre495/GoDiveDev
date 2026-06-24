import Foundation

/// Filters Explore dive-site list rows by name and place hierarchy.
enum ExploreDiveSiteListSearch {

    nonisolated static func isFiltering(query: String) -> Bool {
        CatalogSubstringSearch.isFiltering(query: query)
    }

    nonisolated static func searchHaystacks(for site: DiveSite) -> [String] {
        let displayName = DiveSiteCatalogMatcher.resolvedCatalogSiteName(for: site) ?? site.siteName
        let canonicalCountry = DiveSiteCountryPresentation.canonicalDisplayName(for: site.country)
        return [
            displayName,
            site.siteName,
            ExploreDiveSiteListDisplay.placeSummary(
                country: canonicalCountry,
                region: site.region,
                bodyOfWater: site.bodyOfWater
            ),
            ExploreDiveSiteListDisplay.cityCountryLine(
                country: canonicalCountry,
                region: site.region
            ),
        ] + DiveSiteCountryPresentation.searchTerms(for: site.country)
            + [site.region, site.bodyOfWater]
    }

    nonisolated static func matches(_ site: DiveSite, query: String) -> Bool {
        CatalogSubstringSearch.matchesAny(in: searchHaystacks(for: site), query: query)
    }

    nonisolated static func filtering(_ sites: [DiveSite], query: String) -> [DiveSite] {
        guard isFiltering(query: query) else { return sites }
        return sites.filter { matches($0, query: query) }
    }
}
