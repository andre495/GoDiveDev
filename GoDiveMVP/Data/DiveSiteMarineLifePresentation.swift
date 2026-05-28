import Foundation

/// Marine-life links for a catalog dive-site detail page.
enum DiveSiteMarineLifePresentation {

    struct SightedSpeciesLinkData: Identifiable, Equatable, Sendable {
        var id: String { marineLifeUUID }
        let marineLifeUUID: String
        let displayName: String
    }

    /// Unique species the signed-in user logged at **`diveSiteID`** (common name, A→Z).
    nonisolated static func sightedSpeciesLinks(
        diveSiteID: UUID,
        ownerProfileID: UUID?,
        sightings: [SightingInstance],
        ownerDiveActivityIDs: Set<UUID>,
        catalogByUUID: [String: MarineLifeCatalogSnapshot]
    ) -> [SightedSpeciesLinkData] {
        guard ownerProfileID != nil, !ownerDiveActivityIDs.isEmpty else { return [] }

        var seenUUIDs = Set<String>()
        var links: [SightedSpeciesLinkData] = []

        for sighting in sightings where sighting.diveSiteID == diveSiteID {
            guard let activityID = sighting.diveActivityID,
                  ownerDiveActivityIDs.contains(activityID)
            else { continue }

            guard !seenUUIDs.contains(sighting.marineLifeUUID) else { continue }
            seenUUIDs.insert(sighting.marineLifeUUID)

            let displayName = catalogByUUID[sighting.marineLifeUUID]?.commonName
                ?? sighting.marineLife?.commonName
                ?? "Unknown species"

            links.append(
                SightedSpeciesLinkData(
                    marineLifeUUID: sighting.marineLifeUUID,
                    displayName: displayName
                )
            )
        }

        return links.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
}
