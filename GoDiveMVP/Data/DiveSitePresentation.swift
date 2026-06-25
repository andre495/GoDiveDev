import Foundation

/// Unified read-only dive-site payload for Explore list rows and detail metadata.
struct DiveSiteDisplayRecord: Equatable, Identifiable, Sendable {
    let id: UUID
    let referenceID: String?
    let catalogSiteID: UUID?
    let displayName: String
    let country: String
    let region: String
    let bodyOfWater: String
    let coordinateLine: String
    let entry: String
    let environment: String
    let siteType: String
    let maxDepth: String
    let rating: String
    let siteRating: Int?
    let waterType: String
    let divesLogged: String
    let diveCountLabel: String?
    let listCountry: String
    let searchHaystacks: [String]
    let searchHaystackLowercased: String
    let isReferenceOnly: Bool

    nonisolated var placeLine: String {
        DiveSitePresentation.listPlaceLine(
            country: country == DiveSitePresentation.missingValue ? "" : country,
            region: region == DiveSitePresentation.missingValue ? "" : region,
            bodyOfWater: bodyOfWater == DiveSitePresentation.missingValue ? "" : bodyOfWater
        )
    }

    nonisolated var pinnedLocationLine: String? {
        DiveSitePresentation.pinnedLocationLine(country: country, region: region)
    }

    nonisolated var pinnedDiveCountLabel: String {
        DiveSitePresentation.pinnedDiveCountLabel(count: Int(divesLogged) ?? 0)
    }

    nonisolated var pinnedStarRating: Int {
        DiveSitePresentation.displayPinnedStarRating(from: siteRating)
    }

    /// Detail rows for **Country**, **Region**, and **Body of water** (always three lines).
    nonisolated var placeDetailRows: [(label: String, value: String)] {
        DiveSitePresentation.placeDetailRows(
            country: country,
            region: region,
            bodyOfWater: bodyOfWater
        )
    }

    /// Detail rows for entry, environment, site type, depth, rating, water type, and dive count.
    nonisolated var detailRows: [(label: String, value: String)] {
        [
            (label: "Entry", value: entry),
            (label: "Environment", value: environment),
            (label: "Site type", value: siteType),
            (label: "Max depth", value: maxDepth),
            (label: "Rating", value: rating),
            (label: "Water type", value: waterType),
            (label: "Dives logged here", value: divesLogged),
        ]
    }

    nonisolated func filteredDetailRows(hiding labels: Set<String> = []) -> [(label: String, value: String)] {
        detailRows.filter { !labels.contains($0.label) }
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.referenceID == rhs.referenceID
            && lhs.catalogSiteID == rhs.catalogSiteID
            && lhs.displayName == rhs.displayName
            && lhs.country == rhs.country
            && lhs.region == rhs.region
            && lhs.bodyOfWater == rhs.bodyOfWater
            && lhs.coordinateLine == rhs.coordinateLine
            && lhs.entry == rhs.entry
            && lhs.environment == rhs.environment
            && lhs.siteType == rhs.siteType
            && lhs.maxDepth == rhs.maxDepth
            && lhs.rating == rhs.rating
            && lhs.siteRating == rhs.siteRating
            && lhs.waterType == rhs.waterType
            && lhs.divesLogged == rhs.divesLogged
            && lhs.diveCountLabel == rhs.diveCountLabel
            && lhs.listCountry == rhs.listCountry
            && lhs.searchHaystacks == rhs.searchHaystacks
            && lhs.searchHaystackLowercased == rhs.searchHaystackLowercased
            && lhs.isReferenceOnly == rhs.isReferenceOnly
    }
}

/// Shared labels and builders for catalog **`DiveSite`** + OpenDiveMap reference rows.
enum DiveSitePresentation: Sendable {
    nonisolated static let missingValue = "-"

    nonisolated static func displayValue(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? missingValue : trimmed
    }

    nonisolated static func listPlaceLine(country: String, region: String, bodyOfWater: String) -> String {
        let canonicalCountry = DiveSiteCountryPresentation.canonicalDisplayName(for: country)
        let parts = [canonicalCountry, region, bodyOfWater]
            .map { displayValue($0) }
            .filter { $0 != missingValue }
        return parts.isEmpty ? missingValue : parts.joined(separator: " · ")
    }

    /// Pinned dive-site detail header — **Country** or **Region, Country** when both exist.
    nonisolated static func pinnedLocationLine(country: String, region: String) -> String? {
        let countryValue = country == missingValue ? "" : country
        let regionValue = region == missingValue ? "" : region

        switch (regionValue.isEmpty, countryValue.isEmpty) {
        case (false, false):
            return "\(regionValue), \(countryValue)"
        case (_, false):
            return countryValue
        case (false, true):
            return regionValue
        case (true, true):
            return nil
        }
    }

    nonisolated static func pinnedDiveCountLabel(count: Int) -> String {
        count == 1 ? "1 dive" : "\(count) dives"
    }

    nonisolated static func displayPinnedStarRating(from siteRating: Int?) -> Int {
        guard let siteRating, (1...5).contains(siteRating) else { return 0 }
        return siteRating
    }

    nonisolated static func storageSiteRating(for displayRating: Int) -> Int? {
        guard (1...5).contains(displayRating) else { return nil }
        return displayRating
    }

    nonisolated static func toggledStarRating(current: Int, selectedStar: Int) -> Int {
        guard (1...5).contains(selectedStar) else { return current }
        return selectedStar == current ? 0 : selectedStar
    }

    nonisolated static func isStarRatingEditable(ownerHasVisited: Bool, isReferenceOnly: Bool) -> Bool {
        ownerHasVisited && !isReferenceOnly
    }

    nonisolated static func pinnedStarRatingAccessibilityLabel(rating: Int, isEditable: Bool) -> String {
        let base = rating == 0
            ? "Unrated, 0 out of 5 stars"
            : "Rating \(rating) out of 5 stars"
        guard isEditable else { return base }
        return "\(base). Tap a star to rate this site."
    }

    nonisolated static func placeDetailRows(
        country: String,
        region: String,
        bodyOfWater: String
    ) -> [(label: String, value: String)] {
        let canonicalCountry = DiveSiteCountryPresentation.canonicalDisplayName(
            for: country == missingValue ? "" : country
        )
        return [
            (label: "Country", value: displayValue(canonicalCountry)),
            (label: "Region", value: displayValue(region == missingValue ? "" : region)),
            (label: "Body of water", value: displayValue(bodyOfWater == missingValue ? "" : bodyOfWater)),
        ]
    }

    nonisolated static func listCoordinateLine(latitude: Double?, longitude: Double?) -> String {
        guard let latitude, let longitude else { return missingValue }
        let coordinate = DiveCoordinate(latitude: latitude, longitude: longitude)
        guard DiveMapCoordinateResolver.isUsable(coordinate) else { return missingValue }
        return DiveLocationMapPresentation.coordinateLabel(for: coordinate)
    }

    nonisolated static func listCoordinateLine(for site: DiveSite) -> String {
        listCoordinateLine(latitude: site.latCoords, longitude: site.longCoords)
    }

    nonisolated static func formattedMaxDepth(meters: Int?) -> String {
        guard let meters else { return missingValue }
        return "\(meters) m"
    }

    nonisolated static func formattedRating(_ rating: Int?) -> String {
        guard let rating else { return missingValue }
        return "\(rating) / 5"
    }

    nonisolated static func formattedSiteType(from tags: [String], entry: String = "") -> String {
        let entryNormalized = entry.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let labels = tags
            .filter { !$0.hasPrefix(DiveSiteCatalogMatcher.openDiveMapTagPrefix) }
            .filter { tag in
                guard !entryNormalized.isEmpty else { return true }
                return tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != entryNormalized
            }
            .map { $0.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return labels.isEmpty ? missingValue : labels.joined(separator: ", ")
    }

    nonisolated static func formattedReferenceSiteType(_ topologies: [String]) -> String {
        let labels = topologies
            .map { $0.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return labels.isEmpty ? missingValue : labels.joined(separator: ", ")
    }

    nonisolated static func waterTypeLabel(for site: DiveSite) -> String {
        site.resolvedWaterType.displayTitle
    }

    nonisolated static func waterTypeLabel(environment: String) -> String {
        let trimmed = environment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return missingValue }
        return trimmed.capitalized
    }

    nonisolated static func listSearchHaystackLowercased(
        haystacks: [String],
        coordinateLine: String,
        placeLine: String
    ) -> String {
        var allHaystacks = haystacks
        allHaystacks.append(coordinateLine)
        allHaystacks.append(placeLine)
        return CatalogSearchPresentation.joinedLowercasedHaystacks(allHaystacks)
    }

    nonisolated static func listRecord(
        for site: DiveSite,
        trailingStyle: ExploreDiveSiteRowTrailingStyle = .catalogDefault,
        overrideDiveCountLabel: String? = nil
    ) -> DiveSiteDisplayRecord {
        let displayName = DiveSiteCatalogMatcher.resolvedCatalogSiteName(for: site) ?? site.siteName
        let country = DiveSiteCountryPresentation.canonicalDisplayName(for: site.country)
        let diveCount = site.diveActivities.count
        let displayCountry = displayValue(country)
        let displayRegion = displayValue(site.region)
        let displayBodyOfWater = displayValue(site.bodyOfWater)
        let coordinateLine = listCoordinateLine(for: site)
        let searchHaystacks = ExploreDiveSiteListSearch.searchHaystacks(for: site)
        let placeLine = listPlaceLine(
            country: country,
            region: site.region,
            bodyOfWater: site.bodyOfWater
        )

        return DiveSiteDisplayRecord(
            id: site.id,
            referenceID: DiveSiteCatalogMatcher.referenceID(from: site.siteTags),
            catalogSiteID: site.id,
            displayName: displayName,
            country: displayCountry,
            region: displayRegion,
            bodyOfWater: displayBodyOfWater,
            coordinateLine: coordinateLine,
            entry: displayValue(site.entry),
            environment: displayValue(site.environment),
            siteType: formattedSiteType(from: site.siteTags, entry: site.entry),
            maxDepth: formattedMaxDepth(meters: site.maxDepthMeters),
            rating: formattedRating(site.siteRating),
            siteRating: site.siteRating,
            waterType: waterTypeLabel(for: site),
            divesLogged: "\(diveCount)",
            diveCountLabel: overrideDiveCountLabel
                ?? diveCountLabel(for: site, style: trailingStyle),
            listCountry: ExploreDiveSiteListPresentation.listCountry(from: site),
            searchHaystacks: searchHaystacks,
            searchHaystackLowercased: listSearchHaystackLowercased(
                haystacks: searchHaystacks,
                coordinateLine: coordinateLine,
                placeLine: placeLine
            ),
            isReferenceOnly: false
        )
    }

    nonisolated static func listRecord(for reference: DiveSiteReferenceSnapshot) -> DiveSiteDisplayRecord {
        let displayName = DiveSiteCatalogMatcher.sanitizedReferenceDisplayName(reference.name) ?? reference.name
        let country = DiveSiteCountryPresentation.canonicalDisplayName(for: reference.country)
        let displayCountry = displayValue(country)
        let displayRegion = displayValue("")
        let displayBodyOfWater = displayValue(reference.seaName)
        let coordinateLine = listCoordinateLine(latitude: reference.latitude, longitude: reference.longitude)
        let searchHaystacks = ExploreReferenceSiteListSearch.searchHaystacks(for: reference)
        let placeLine = listPlaceLine(country: country, region: "", bodyOfWater: reference.seaName)

        return DiveSiteDisplayRecord(
            id: ExploreSiteScopePresentation.stableMapPinID(forReferenceID: reference.id),
            referenceID: reference.id,
            catalogSiteID: nil,
            displayName: displayName,
            country: displayCountry,
            region: displayRegion,
            bodyOfWater: displayBodyOfWater,
            coordinateLine: coordinateLine,
            entry: displayValue(reference.entry),
            environment: displayValue(reference.environment),
            siteType: formattedReferenceSiteType(reference.topologies),
            maxDepth: formattedMaxDepth(meters: reference.maxDepthMeters),
            rating: missingValue,
            siteRating: nil,
            waterType: waterTypeLabel(environment: reference.environment),
            divesLogged: "0",
            diveCountLabel: nil,
            listCountry: ExploreDiveSiteListPresentation.listCountry(from: reference),
            searchHaystacks: searchHaystacks,
            searchHaystackLowercased: listSearchHaystackLowercased(
                haystacks: searchHaystacks,
                coordinateLine: coordinateLine,
                placeLine: placeLine
            ),
            isReferenceOnly: true
        )
    }

    nonisolated static func listRecords(
        for sites: [DiveSite],
        trailingStyle: ExploreDiveSiteRowTrailingStyle = .catalogDefault
    ) -> [DiveSiteDisplayRecord] {
        sites.map { listRecord(for: $0, trailingStyle: trailingStyle) }
    }

    nonisolated static func listRecords(for reference: [DiveSiteReferenceSnapshot]) -> [DiveSiteDisplayRecord] {
        reference.map { listRecord(for: $0) }
    }

    private nonisolated static func diveCountLabel(
        for site: DiveSite,
        style: ExploreDiveSiteRowTrailingStyle
    ) -> String? {
        guard style == .catalogDefault else { return nil }
        let diveCount = site.diveActivities.count
        guard diveCount > 0 else { return nil }
        return diveCount == 1 ? "1 dive" : "\(diveCount) dives"
    }
}
