import Foundation

/// Filters Explore dive-site list rows by name and place hierarchy.
enum ExploreDiveSiteListSearch {

    nonisolated static func isFiltering(query: String) -> Bool {
        CatalogSubstringSearch.isFiltering(query: query)
    }

    nonisolated static func searchHaystacks(for site: DiveSite) -> [String] {
        searchHaystacks(
            siteName: site.siteName,
            country: site.country,
            region: site.region,
            bodyOfWater: site.bodyOfWater,
            siteTags: site.siteTags
        )
    }

    /// Same haystacks as the **`DiveSite`** overload, for Sendable site seeds (off-main search index).
    nonisolated static func searchHaystacks(
        siteName: String,
        country: String,
        region: String,
        bodyOfWater: String,
        siteTags: [String],
        reference: [DiveSiteReferenceSnapshot] = DiveSiteReferenceCatalog.bundledReference()
    ) -> [String] {
        let displayName = DiveSiteCatalogMatcher.resolvedCatalogSiteName(
            siteName: siteName,
            siteTags: siteTags,
            reference: reference
        ) ?? siteName
        let canonicalCountry = DiveSiteCountryPresentation.canonicalDisplayName(for: country)
        return [
            displayName,
            siteName,
            ExploreDiveSiteListDisplay.placeSummary(
                country: canonicalCountry,
                region: region,
                bodyOfWater: bodyOfWater
            ),
            ExploreDiveSiteListDisplay.cityCountryLine(
                country: canonicalCountry,
                region: region
            ),
        ] + DiveSiteCountryPresentation.searchTerms(for: country)
            + [region, bodyOfWater]
    }

    nonisolated static func matches(_ site: DiveSite, query: String) -> Bool {
        CatalogSubstringSearch.matchesAny(in: searchHaystacks(for: site), query: query)
    }

    nonisolated static func filtering(_ sites: [DiveSite], query: String) -> [DiveSite] {
        guard isFiltering(query: query) else { return sites }
        return sites.filter { matches($0, query: query) }
    }
}
