import Foundation

/// One country bucket in the Explore dive-site list.
struct ExploreDiveSiteListSection: Identifiable, Equatable, Sendable {
    let title: String
    let rows: [ExploreDiveSiteRowDisplayData]

    var id: String { title }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title && lhs.rows == rhs.rows
    }
}

/// Section titles and grouping for Explore list mode.
enum ExploreDiveSiteListPresentation: Sendable {
    nonisolated static let unknownCountrySectionTitle = "Unknown location"

    nonisolated static func listCountry(from site: DiveSite) -> String {
        normalizedListCountry(site.country)
    }

    nonisolated static func listCountry(from reference: DiveSiteReferenceSnapshot) -> String {
        normalizedListCountry(reference.country)
    }

    /// Unified place label for OpenDiveMap reference rows (same field order as catalog).
    nonisolated static func referencePlaceLine(for reference: DiveSiteReferenceSnapshot) -> String? {
        let line = DiveSitePresentation.listRecord(for: reference).placeLine
        return line == DiveSitePresentation.missingValue ? nil : line
    }

    nonisolated static func sections(
        from rows: [ExploreDiveSiteRowDisplayData]
    ) -> [ExploreDiveSiteListSection] {
        let grouped = Dictionary(grouping: rows, by: \.listCountry)
        return grouped.keys.sorted(by: sortSectionTitles).map { title in
            let sectionRows = uniqueRowsPreservingOrder(grouped[title, default: []])
                .sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
            return ExploreDiveSiteListSection(title: title, rows: sectionRows)
        }
    }

    private nonisolated static func uniqueRowsPreservingOrder(
        _ rows: [ExploreDiveSiteRowDisplayData]
    ) -> [ExploreDiveSiteRowDisplayData] {
        var seenIDs = Set<UUID>()
        var seenReferenceIDs = Set<String>()
        return rows.filter { row in
            if let referenceID = row.referenceID {
                guard seenReferenceIDs.insert(referenceID).inserted else { return false }
                return true
            }
            return seenIDs.insert(row.id).inserted
        }
    }

    private nonisolated static func normalizedListCountry(_ raw: String) -> String {
        let canonical = DiveSiteCountryPresentation.canonicalDisplayName(for: raw)
        return canonical.isEmpty ? unknownCountrySectionTitle : canonical
    }

    private nonisolated static func sortSectionTitles(_ lhs: String, _ rhs: String) -> Bool {
        switch (lhs == unknownCountrySectionTitle, rhs == unknownCountrySectionTitle) {
        case (true, true):
            return false
        case (true, false):
            return false
        case (false, true):
            return true
        case (false, false):
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }
}
