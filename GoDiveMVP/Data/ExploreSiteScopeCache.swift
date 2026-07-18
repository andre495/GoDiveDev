import Foundation

/// Precomputed Explore logbook / all-sites payloads so scope toggles swap arrays instead of rebuilding.
enum ExploreSiteScopeCache: Sendable {
    struct Snapshot: Equatable, Sendable {
        let logbookSiteIDs: Set<UUID>
        let logbookPlottableSites: [ExploreCatalogMapPresentation.PlottedSite]
        let allSitesPlottableSites: [ExploreCatalogMapPresentation.PlottedSite]
        let logbookPlottableSignature: String
        let allSitesPlottableSignature: String
        let logbookListRows: [ExploreDiveSiteRowDisplayData]
        let allSitesListRows: [ExploreDiveSiteRowDisplayData]
        let showsSiteScopeToggle: Bool
        let hasLogbookSites: Bool
        let hasAllSitesCatalog: Bool

        static let empty = Snapshot(
            logbookSiteIDs: [],
            logbookPlottableSites: [],
            allSitesPlottableSites: [],
            logbookPlottableSignature: ExploreCatalogMapPresentation.sitesChangeSignature(for: []),
            allSitesPlottableSignature: ExploreCatalogMapPresentation.sitesChangeSignature(for: []),
            logbookListRows: [],
            allSitesListRows: [],
            showsSiteScopeToggle: false,
            hasLogbookSites: false,
            hasAllSitesCatalog: false
        )

        nonisolated func plottableSites(for scope: ExploreSiteScope) -> [ExploreCatalogMapPresentation.PlottedSite] {
            switch scope {
            case .logbook:
                return logbookPlottableSites
            case .allSites:
                return allSitesPlottableSites
            }
        }

        nonisolated func plottableSignature(for scope: ExploreSiteScope) -> String {
            switch scope {
            case .logbook:
                return logbookPlottableSignature
            case .allSites:
                return allSitesPlottableSignature
            }
        }

        nonisolated func listRows(for scope: ExploreSiteScope) -> [ExploreDiveSiteRowDisplayData] {
            switch scope {
            case .logbook:
                return logbookListRows
            case .allSites:
                return allSitesListRows
            }
        }

        nonisolated func hasScopedContent(for scope: ExploreSiteScope) -> Bool {
            switch scope {
            case .logbook:
                return hasLogbookSites
            case .allSites:
                return hasAllSitesCatalog
            }
        }
    }

    nonisolated static func syncToken(
        ownerProfileID: UUID?,
        catalogSiteCount: Int,
        userSiteCount: Int = 0,
        ownerActivitySiteLinkSignature: Int
    ) -> String {
        "\(ownerProfileID?.uuidString ?? "nil")|\(catalogSiteCount)|\(userSiteCount)|\(ownerActivitySiteLinkSignature)"
    }

    nonisolated static func ownerActivitySiteLinkSignature(_ ownerActivities: [DiveActivity]) -> Int {
        var hasher = Hasher()
        for activity in ownerActivities {
            hasher.combine(activity.diveSiteID)
        }
        return hasher.finalize()
    }

    nonisolated static func make(
        ownerProfileID: UUID?,
        catalog: [DiveSite],
        userSites: [UserDiveSite] = [],
        ownerActivities: [DiveActivity]
    ) -> Snapshot {
        let reference = DiveSiteReferenceCatalog.bundledReference()
        let logbookSiteIDs = ExploreSiteScopePresentation.logbookSiteIDs(
            ownerActivities: ownerActivities,
            ownerProfileID: ownerProfileID
        )
        let logbookCatalogSites = ExploreSiteScopePresentation.logbookCatalogSites(
            catalog: catalog,
            logbookSiteIDs: logbookSiteIDs
        )
        let logbookUserSites = userSites.filter { logbookSiteIDs.contains($0.id) }
        // Pure user-created sites only on All Sites — OpenDiveMap snapshots are already in the reference layer.
        let allSitesUserSites = logbookUserSites.filter { $0.openDiveMapReferenceID == nil }
        let logbookUserPlottable = ExploreCatalogMapPresentation.plottableSites(from: logbookUserSites)
        let logbookUserIDs = Set(logbookUserPlottable.map(\.id))
        let logbookCatalogPlottable = ExploreSiteScopePresentation.plottableSites(
            scope: .logbook,
            catalog: catalog,
            logbookSiteIDs: logbookSiteIDs,
            reference: reference
        ).filter { !logbookUserIDs.contains($0.id) }
        let logbookPlottable = ExploreCatalogMapPresentation.deduplicatingPlottableSites(
            logbookUserPlottable + logbookCatalogPlottable
        )
        let allSitesPlottable = ExploreCatalogMapPresentation.deduplicatingPlottableSites(
            ExploreSiteScopePresentation.plottableSites(
                scope: .allSites,
                catalog: catalog,
                logbookSiteIDs: logbookSiteIDs,
                reference: reference
            ) + ExploreCatalogMapPresentation.plottableSites(from: allSitesUserSites)
        )
        let logbookUserRows = DiveSitePresentation.listRecords(for: logbookUserSites)
        let logbookUserRowIDs = Set(logbookUserRows.map(\.id))
        let logbookCatalogRows = ExploreSiteScopePresentation.catalogListRows(
            scope: .logbook,
            catalog: catalog,
            logbookSiteIDs: logbookSiteIDs,
            reference: reference,
            query: ""
        ).filter { !logbookUserRowIDs.contains($0.id) }
        let logbookRows = logbookUserRows + logbookCatalogRows
        let allSitesRows = ExploreSiteScopePresentation.catalogListRows(
            scope: .allSites,
            catalog: catalog,
            logbookSiteIDs: logbookSiteIDs,
            reference: reference,
            query: ""
        ) + DiveSitePresentation.listRecords(for: allSitesUserSites)

        return Snapshot(
            logbookSiteIDs: logbookSiteIDs,
            logbookPlottableSites: logbookPlottable,
            allSitesPlottableSites: allSitesPlottable,
            logbookPlottableSignature: ExploreCatalogMapPresentation.sitesChangeSignature(for: logbookPlottable),
            allSitesPlottableSignature: ExploreCatalogMapPresentation.sitesChangeSignature(for: allSitesPlottable),
            logbookListRows: logbookRows,
            allSitesListRows: allSitesRows,
            showsSiteScopeToggle: !reference.isEmpty || !logbookUserSites.isEmpty,
            hasLogbookSites: !logbookCatalogSites.isEmpty || !logbookUserSites.isEmpty,
            hasAllSitesCatalog: !reference.isEmpty || !userSites.isEmpty
        )
    }

    nonisolated static func filteringListRows(
        _ rows: [ExploreDiveSiteRowDisplayData],
        scope: ExploreSiteScope,
        query: String
    ) -> [ExploreDiveSiteRowDisplayData] {
        let isFiltering: Bool
        switch scope {
        case .logbook:
            isFiltering = ExploreDiveSiteListSearch.isFiltering(query: query)
        case .allSites:
            isFiltering = ExploreReferenceSiteListSearch.isFiltering(query: query)
        }
        guard isFiltering else { return rows }
        return rows.filter { matchesListRow($0, query: query) }
    }

    private nonisolated static func matchesListRow(
        _ row: ExploreDiveSiteRowDisplayData,
        query: String
    ) -> Bool {
        CatalogSubstringSearch.matchesPrelowercased(row.searchHaystackLowercased, query: query)
    }
}
