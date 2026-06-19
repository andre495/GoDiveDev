import Foundation

/// A dive-site match shown under the Explore map search field.
struct ExploreDiveSiteSearchSuggestion: Identifiable, Equatable, Sendable {
    let id: String
    let rowDisplayData: ExploreDiveSiteRowDisplayData
    let selection: ExploreMapSiteSelection
    let coordinate: DiveCoordinate

    nonisolated init(
        rowDisplayData: ExploreDiveSiteRowDisplayData,
        selection: ExploreMapSiteSelection,
        coordinate: DiveCoordinate
    ) {
        self.rowDisplayData = rowDisplayData
        self.selection = selection
        self.coordinate = coordinate
        switch selection {
        case .catalog(let siteID):
            id = "catalog:\(siteID.uuidString)"
        case .reference(let referenceID):
            id = "reference:\(referenceID)"
        }
    }

    var siteName: String { rowDisplayData.displayName }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.rowDisplayData == rhs.rowDisplayData
            && lhs.selection == rhs.selection
            && lhs.coordinate == rhs.coordinate
    }
}

/// Map search dropdown suggestions derived from scoped catalog / reference rows.
enum ExploreDiveSiteSearchPresentation: Sendable {
    nonisolated static let maxSuggestionCount = 8

    nonisolated static func showsSuggestions(
        viewMode: ExploreViewMode,
        query: String,
        mapFocusedSelection: ExploreMapSiteSelection?
    ) -> Bool {
        guard viewMode == .map else { return false }
        guard mapFocusedSelection == nil else { return false }
        switch query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        case true:
            return false
        case false:
            return true
        }
    }

    nonisolated static func suggestions(
        scope: ExploreSiteScope,
        catalog: [DiveSite],
        logbookSiteIDs: Set<UUID>,
        reference: [DiveSiteReferenceSnapshot],
        plottableSites: [ExploreCatalogMapPresentation.PlottedSite],
        query: String
    ) -> [ExploreDiveSiteSearchSuggestion] {
        let rows = ExploreSiteScopePresentation.catalogListRows(
            scope: scope,
            catalog: catalog,
            logbookSiteIDs: logbookSiteIDs,
            reference: reference,
            query: query
        )
        guard !rows.isEmpty else { return [] }

        return rows.prefix(maxSuggestionCount).compactMap { row in
            let selection = ExploreSiteScopePresentation.rowSelection(for: row)
            guard let coordinate = plottableSites.first(where: { $0.selection == selection })?.coordinate
            else { return nil }
            return ExploreDiveSiteSearchSuggestion(
                rowDisplayData: row,
                selection: selection,
                coordinate: coordinate
            )
        }
    }
}
