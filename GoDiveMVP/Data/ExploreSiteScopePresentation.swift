import CryptoKit
import Foundation

/// Explore map pin selection — catalog **`DiveSite`** or read-only OpenDiveMap reference row.
enum ExploreMapSiteSelection: Sendable {
    case catalog(UUID)
    case reference(String)
}

extension ExploreMapSiteSelection: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.catalog(let left), .catalog(let right)):
            return left == right
        case (.reference(let left), .reference(let right)):
            return left == right
        default:
            return false
        }
    }
}

extension ExploreMapSiteSelection: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        switch self {
        case .catalog(let siteID):
            hasher.combine(0)
            hasher.combine(siteID)
        case .reference(let referenceID):
            hasher.combine(1)
            hasher.combine(referenceID)
        }
    }
}

/// Logbook-linked catalog sites vs the bundled OpenDiveMap reference catalog.
enum ExploreSiteScope: String, CaseIterable, Identifiable, Sendable {
    case logbook
    case allSites

    var id: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .logbook: "My sites"
        case .allSites: "All sites"
        }
    }

    var shortTitle: String {
        switch self {
        case .logbook: "My Sites"
        case .allSites: "All Sites"
        }
    }

    var systemImage: String {
        switch self {
        case .logbook: "book.closed.fill"
        case .allSites: "globe.americas.fill"
        }
    }
}

enum ExploreSiteScopePresentation: Sendable {
    /// Empty logbook → **All Sites**; any logged activities → **My Sites**.
    nonisolated static func defaultScope(hasLoggedActivities: Bool) -> ExploreSiteScope {
        hasLoggedActivities ? .logbook : .allSites
    }

    nonisolated static func logbookSiteIDs(
        ownerActivities: [DiveActivity],
        ownerProfileID: UUID?
    ) -> Set<UUID> {
        guard ownerProfileID != nil else { return [] }
        return Set(ownerActivities.compactMap(\.diveSiteID))
    }

    nonisolated static func logbookCatalogSites(
        catalog: [DiveSite],
        logbookSiteIDs: Set<UUID>
    ) -> [DiveSite] {
        catalog.filter { logbookSiteIDs.contains($0.id) }
    }

    nonisolated static func catalogSiteByOpenDiveMapID(_ catalog: [DiveSite]) -> [String: DiveSite] {
        var byReferenceID: [String: DiveSite] = [:]
        for site in catalog {
            guard let referenceID = DiveSiteCatalogMatcher.referenceID(from: site.siteTags) else { continue }
            byReferenceID[referenceID] = site
        }
        return byReferenceID
    }

    nonisolated static func stableMapPinID(forReferenceID referenceID: String) -> UUID {
        let digest = SHA256.hash(data: Data("opendivemap:\(referenceID)".utf8))
        let bytes = Array(digest.prefix(16))
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            )
        )
    }

    nonisolated static func plottableSites(
        scope: ExploreSiteScope,
        catalog: [DiveSite],
        logbookSiteIDs: Set<UUID>,
        reference: [DiveSiteReferenceSnapshot]
    ) -> [ExploreCatalogMapPresentation.PlottedSite] {
        switch scope {
        case .logbook:
            return ExploreCatalogMapPresentation.plottableSites(
                from: logbookCatalogSites(catalog: catalog, logbookSiteIDs: logbookSiteIDs)
            )
        case .allSites:
            let catalogByReferenceID = catalogSiteByOpenDiveMapID(catalog)
            let referencePlotted = reference.compactMap { snapshot in
                plottedReferenceSite(
                    snapshot,
                    catalogByReferenceID: catalogByReferenceID,
                    logbookSiteIDs: logbookSiteIDs
                )
            }
            let supplementalPlotted = supplementalLogbookPlottedSites(
                catalog: catalog,
                logbookSiteIDs: logbookSiteIDs,
                reference: reference
            )
            return referencePlotted + supplementalPlotted
        }
    }

    nonisolated static func catalogListRows(
        scope: ExploreSiteScope,
        catalog: [DiveSite],
        logbookSiteIDs: Set<UUID>,
        reference: [DiveSiteReferenceSnapshot],
        query: String
    ) -> [ExploreDiveSiteRowDisplayData] {
        switch scope {
        case .logbook:
            let sites = logbookCatalogSites(catalog: catalog, logbookSiteIDs: logbookSiteIDs)
            let filtered = ExploreDiveSiteListSearch.filtering(sites, query: query)
            return ExploreDiveSiteListDisplay.rowData(for: filtered)
        case .allSites:
            let filteredReference = ExploreReferenceSiteListSearch.filtering(reference, query: query)
            let referenceRows = ExploreReferenceSiteListDisplay.rowData(for: filteredReference)
            let supplementalSites = supplementalLogbookCatalogSites(
                catalog: catalog,
                logbookSiteIDs: logbookSiteIDs,
                reference: reference
            )
            let filteredSupplemental = ExploreDiveSiteListSearch.filtering(supplementalSites, query: query)
            let supplementalRows = ExploreDiveSiteListDisplay.rowData(for: filteredSupplemental)
            return (referenceRows + supplementalRows).sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
    }

    nonisolated static func rowSelection(for row: ExploreDiveSiteRowDisplayData) -> ExploreMapSiteSelection {
        if let referenceID = row.referenceID {
            return .reference(referenceID)
        }
        return .catalog(row.id)
    }

    /// Logbook-linked catalog sites that are not already represented by a bundled OpenDiveMap row.
    nonisolated static func supplementalLogbookCatalogSites(
        catalog: [DiveSite],
        logbookSiteIDs: Set<UUID>,
        reference: [DiveSiteReferenceSnapshot]
    ) -> [DiveSite] {
        let referenceIDs = Set(reference.map(\.id))
        return logbookCatalogSites(catalog: catalog, logbookSiteIDs: logbookSiteIDs)
            .filter { site in
                guard let referenceID = DiveSiteCatalogMatcher.referenceID(from: site.siteTags) else {
                    return true
                }
                return !referenceIDs.contains(referenceID)
            }
    }

    nonisolated static func supplementalLogbookPlottedSites(
        catalog: [DiveSite],
        logbookSiteIDs: Set<UUID>,
        reference: [DiveSiteReferenceSnapshot]
    ) -> [ExploreCatalogMapPresentation.PlottedSite] {
        supplementalLogbookCatalogSites(
            catalog: catalog,
            logbookSiteIDs: logbookSiteIDs,
            reference: reference
        )
        .compactMap { site in
            ExploreCatalogMapPresentation.plottableSites(from: [site]).first
        }
    }

    private nonisolated static func plottedReferenceSite(
        _ snapshot: DiveSiteReferenceSnapshot,
        catalogByReferenceID: [String: DiveSite],
        logbookSiteIDs: Set<UUID>
    ) -> ExploreCatalogMapPresentation.PlottedSite? {
        guard let lat = snapshot.latitude, let lon = snapshot.longitude else { return nil }
        let coordinate = DiveCoordinate(latitude: lat, longitude: lon)
        guard DiveMapCoordinateResolver.isUsable(coordinate) else { return nil }

        if let catalogSite = catalogByReferenceID[snapshot.id] {
            let siteName = DiveSiteCatalogMatcher.resolvedCatalogSiteName(for: catalogSite) ?? catalogSite.siteName
            return ExploreCatalogMapPresentation.PlottedSite(
                id: catalogSite.id,
                siteName: siteName,
                coordinate: coordinate,
                selection: .catalog(catalogSite.id),
                isVisited: logbookSiteIDs.contains(catalogSite.id)
            )
        }

        return ExploreCatalogMapPresentation.PlottedSite(
            id: stableMapPinID(forReferenceID: snapshot.id),
            siteName: DiveSiteCatalogMatcher.sanitizedReferenceDisplayName(snapshot.name) ?? snapshot.name,
            coordinate: coordinate,
            selection: .reference(snapshot.id),
            isVisited: false
        )
    }
}

/// Reference catalog list rows for **Explore** when scope is **All sites**.
enum ExploreReferenceSiteListDisplay {
    nonisolated static func rowData(for reference: [DiveSiteReferenceSnapshot]) -> [ExploreDiveSiteRowDisplayData] {
        DiveSitePresentation.listRecords(for: reference)
    }
}

/// Filters OpenDiveMap reference rows by name and place fields.
enum ExploreReferenceSiteListSearch {
    nonisolated static func isFiltering(query: String) -> Bool {
        CatalogSubstringSearch.isFiltering(query: query)
    }

    nonisolated static func searchHaystacks(for snapshot: DiveSiteReferenceSnapshot) -> [String] {
        let canonicalCountry = DiveSiteCountryPresentation.canonicalDisplayName(for: snapshot.country)
        return [
            snapshot.name,
            snapshot.countryCode,
            ExploreDiveSiteListDisplay.cityCountryLine(
                country: canonicalCountry,
                region: snapshot.seaName
            ),
            snapshot.seaName,
        ] + DiveSiteCountryPresentation.searchTerms(for: snapshot.country)
    }

    nonisolated static func matches(_ snapshot: DiveSiteReferenceSnapshot, query: String) -> Bool {
        CatalogSubstringSearch.matchesAny(in: searchHaystacks(for: snapshot), query: query)
    }

    nonisolated static func filtering(
        _ reference: [DiveSiteReferenceSnapshot],
        query: String
    ) -> [DiveSiteReferenceSnapshot] {
        guard isFiltering(query: query) else { return reference }
        return reference.filter { matches($0, query: query) }
    }
}

/// Bottom placement for **Explore** **My Sites / All Sites** toggle — pinned just above the root tab bar.
enum ExploreSiteScopeChromePresentation {
    /// Segment row (**32 pt**) + shell padding (**4 pt** × 2).
    nonisolated static let toggleChromeHeight: CGFloat = 40

    /// Hairline gap between the toggle and the tab bar top (tab content geometry already ends there).
    nonisolated static let spacingAboveTabBar: CGFloat = 4

    /// Bottom toggle hides while search is focused — scope control uses **`ExploreSiteScopeKeyboardChrome`** above the keyboard.
    nonisolated static func showsBottomToggle(isSearchFocused: Bool) -> Bool {
        !isSearchFocused
    }

    /// Scope toggle above the software keyboard during active site search.
    nonisolated static func showsKeyboardAdjacentToggle(
        isSearchFocused: Bool,
        showsSiteScopeToggle: Bool,
        isNavigationStackAtRoot: Bool
    ) -> Bool {
        isSearchFocused && showsSiteScopeToggle && isNavigationStackAtRoot
    }

    nonisolated static func paddingAboveTabBar(safeAreaBottom _: CGFloat = 0) -> CGFloat {
        spacingAboveTabBar
    }

    /// Extra list scroll inset when the scope toggle is visible above the tab bar.
    nonisolated static var listExtraBottomInset: CGFloat {
        toggleChromeHeight + spacingAboveTabBar
    }
}

private extension String {
    nonisolated var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
