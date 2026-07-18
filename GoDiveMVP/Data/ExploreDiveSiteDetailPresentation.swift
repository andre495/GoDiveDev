import Foundation

/// Map hero + tagged-media selection for **Explore** dive-site detail (catalog + reference).
enum ExploreDiveSiteDetailPresentation: Sendable {

    nonisolated static func mapPins(for site: DiveSite) -> [TripDetailMapPin] {
        guard let pin = catalogMapPin(for: site) else { return [] }
        return [pin]
    }

    nonisolated static func mapPins(for site: UserDiveSite) -> [TripDetailMapPin] {
        guard let pin = userMapPin(for: site) else { return [] }
        return [pin]
    }

    nonisolated static func mapPins(for reference: DiveSiteReferenceSnapshot) -> [TripDetailMapPin] {
        guard let pin = referenceMapPin(for: reference) else { return [] }
        return [pin]
    }

    nonisolated static func catalogMapPin(for site: DiveSite) -> TripDetailMapPin? {
        guard let coordinate = DiveMapCoordinateResolver.coordinate(from: site),
              DiveMapCoordinateResolver.isUsable(coordinate)
        else { return nil }

        let title = DiveSiteCatalogMatcher.resolvedCatalogSiteName(for: site) ?? site.siteName
        return TripDetailMapPin(
            id: "site-\(site.id.uuidString)",
            title: title,
            coordinate: coordinate,
            kind: .completed,
            siteID: site.id
        )
    }

    nonisolated static func userMapPin(for site: UserDiveSite) -> TripDetailMapPin? {
        guard let coordinate = DiveMapCoordinateResolver.coordinate(from: site),
              DiveMapCoordinateResolver.isUsable(coordinate)
        else { return nil }

        return TripDetailMapPin(
            id: "user-site-\(site.id.uuidString)",
            title: site.siteName,
            coordinate: coordinate,
            kind: .completed,
            siteID: site.id
        )
    }

    nonisolated static func referenceMapPin(for reference: DiveSiteReferenceSnapshot) -> TripDetailMapPin? {
        guard let latitude = reference.latitude,
              let longitude = reference.longitude
        else { return nil }

        let coordinate = DiveCoordinate(latitude: latitude, longitude: longitude)
        guard DiveMapCoordinateResolver.isUsable(coordinate) else { return nil }

        let title = DiveSiteCatalogMatcher.sanitizedReferenceDisplayName(reference.name) ?? reference.name
        return TripDetailMapPin(
            id: "reference-\(reference.id)",
            title: title,
            coordinate: coordinate,
            kind: .planned,
            siteID: nil
        )
    }

    nonisolated static func initialHeroTaggedMediaPhotoID(from photos: [DiveMediaPhoto]) -> UUID? {
        DiveBuddyDetailPresentation.randomHeroTaggedMedia(from: photos)?.id
    }

    nonisolated static func showsHeroModeToggle(
        hasTaggedMedia: Bool,
        hasMapPin: Bool
    ) -> Bool {
        hasTaggedMedia && hasMapPin
    }

    /// **`true`** when the hero should open on the map (coordinates, no tagged media).
    nonisolated static func prefersMapHero(hasTaggedMedia: Bool, hasMapPin: Bool) -> Bool {
        !hasTaggedMedia && hasMapPin
    }

    /// Wait for the owner dive roster query before defaulting to map-only (avoids racing sightings).
    nonisolated static func canDefaultHeroMode(
        hasOwnerProfile: Bool,
        ownerDiveQueryReady: Bool
    ) -> Bool {
        !hasOwnerProfile || ownerDiveQueryReady
    }
}
