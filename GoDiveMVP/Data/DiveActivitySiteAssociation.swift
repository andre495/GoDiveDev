import Foundation
import SwiftData

/// Links imported **`DiveActivity`** rows to catalog **`DiveSite`** rows (exact import **`siteName`** first; GPS only when the dive has no site name).
enum DiveActivitySiteAssociation {
    static func fetchCatalogSites(modelContext: ModelContext) throws -> [DiveSite] {
        try modelContext.fetch(FetchDescriptor<DiveSite>())
    }

    /// Tries to set **`diveSite`** / **`diveSiteID`** when not already linked.
    static func applyBestMatch(
        to activity: DiveActivity,
        catalogSites: [DiveSite],
        modelContext: ModelContext? = nil
    ) {
        guard activity.diveSiteID == nil else { return }
        guard let site = previewBestMatch(for: activity, catalogSites: catalogSites) else { return }
        if let modelContext {
            link(activity, to: site, modelContext: modelContext)
        } else {
            link(activity, to: site)
        }
        let reference = DiveSiteReferenceCatalog.bundledReference()
        _ = DiveSiteCatalogMatcher.enrichCatalogSiteFromOpenDiveMapIfNeeded(
            site,
            catalogSites: catalogSites,
            reference: reference
        )
        if let modelContext {
            _ = ensureSyncedUserDiveSiteSnapshot(
                of: site,
                owner: activity.owner,
                modelContext: modelContext
            )
        }
    }

    /// Same rules as **`applyBestMatch`**, without mutating **`diveSite`** (import datetime / timezone lookup).
    static func previewBestMatch(for activity: DiveActivity, catalogSites: [DiveSite]) -> DiveSite? {
        guard activity.diveSiteID == nil else { return catalogSites.first { $0.id == activity.diveSiteID } }

        if let siteName = trimmedSiteName(activity.siteName) {
            let exactMatches = DiveMapCoordinateResolver.exactMatchingSites(forSiteName: siteName, in: catalogSites)
            if let matched = disambiguateSiteMatches(exactMatches, entryCoordinate: activity.entryCoordinate) {
                return matched
            }
        } else if let entry = activity.entryCoordinate,
                  DiveMapCoordinateResolver.isUsable(entry),
                  !catalogSites.isEmpty,
                  let site = DiveSiteCoordinateMatcher.bestMatch(for: entry, in: catalogSites) {
            return site
        }

        return previewBestOpenDiveMapCatalogMatch(for: activity, catalogSites: catalogSites)
    }

    /// Links when a prior import already created a catalog row tagged with the matched OpenDiveMap id.
    static func previewBestOpenDiveMapCatalogMatch(
        for activity: DiveActivity,
        catalogSites: [DiveSite],
        reference: [DiveSiteReferenceSnapshot] = DiveSiteReferenceCatalog.bundledReference()
    ) -> DiveSite? {
        guard activity.diveSiteID == nil else { return catalogSites.first { $0.id == activity.diveSiteID } }
        guard let match = bestOpenDiveMapReferenceMatch(for: activity, reference: reference) else { return nil }
        return DiveSiteCatalogMatcher.catalogSite(forReferenceID: match.snapshot.id, in: catalogSites)
    }

    /// Import **`siteName`** → exact catalog name match only (never a different nearby site). Duplicate names disambiguate by GPS within that name set.
    private static func disambiguateSiteMatches(
        _ matches: [DiveSite],
        entryCoordinate: DiveCoordinate?
    ) -> DiveSite? {
        switch matches.count {
        case 0:
            return nil
        case 1:
            return matches[0]
        default:
            if let entry = entryCoordinate,
               DiveMapCoordinateResolver.isUsable(entry),
               let nearest = DiveSiteCoordinateMatcher.bestMatch(for: entry, in: matches) {
                return nearest
            }
            return matches[0]
        }
    }

    static func link(_ activity: DiveActivity, to site: DiveSite) {
        activity.diveSiteID = site.id
        activity.diveWaterType = site.resolvedWaterType
        DiveActivityDiverWeightDefaults.applyInheritedDefaults(to: activity)
    }

    /// Links a dive to a catalog site and upserts a CloudKit-synced **`UserDiveSite`** snapshot.
    static func link(_ activity: DiveActivity, to site: DiveSite, modelContext: ModelContext) {
        link(activity, to: site)
        _ = ensureSyncedUserDiveSiteSnapshot(
            of: site,
            owner: activity.owner,
            modelContext: modelContext
        )
    }

    static func link(_ activity: DiveActivity, to site: UserDiveSite) {
        activity.diveSiteID = site.id
        activity.diveWaterType = site.resolvedWaterType
        DiveActivityDiverWeightDefaults.applyInheritedDefaults(to: activity)
    }

    /// Ensures an OpenDiveMap / catalog link has a user-store row that can sync with the dive.
    @discardableResult
    static func ensureSyncedUserDiveSiteSnapshot(
        of catalogSite: DiveSite,
        owner: UserProfile?,
        modelContext: ModelContext
    ) -> UserDiveSite {
        if let existing = try? DiveLinkedSiteResolver.existingUserDiveSite(
            id: catalogSite.id,
            modelContext: modelContext
        ) {
            if existing.openDiveMapReferenceID == nil,
               let referenceID = DiveSiteCatalogMatcher.referenceID(from: catalogSite.siteTags) {
                existing.openDiveMapReferenceID = referenceID
            }
            if existing.catalogDiveSiteID == nil {
                existing.catalogDiveSiteID = catalogSite.id
            }
            if existing.owner == nil, let owner {
                existing.owner = owner
                existing.ownerProfileID = owner.id
            }
            return existing
        }
        let snapshot = UserDiveSite.snapshot(from: catalogSite, owner: owner)
        modelContext.insert(snapshot)
        return snapshot
    }

    static func unlink(_ activity: DiveActivity) {
        activity.diveSiteID = nil
    }

    /// Links inserted dives to catalog sites; optionally creates **`DiveSite`** rows for unmatched import site names.
    @MainActor
    @discardableResult
    static func applySiteLinksForImportedActivities(
        _ activities: [DiveActivity],
        catalogSites: inout [DiveSite],
        createMissingSites: Bool,
        modelContext: ModelContext
    ) -> Int {
        var createdSiteCount = 0
        let reference = DiveSiteReferenceCatalog.bundledReference()
        for activity in activities {
            applyBestMatch(to: activity, catalogSites: catalogSites, modelContext: modelContext)
            guard activity.diveSiteID == nil else { continue }
            switch applyOpenDiveMapSiteLinkIfNeeded(
                to: activity,
                catalogSites: &catalogSites,
                modelContext: modelContext,
                reference: reference,
                createSiteWhenMissing: true
            ) {
            case .noMatch:
                break
            case .linkedExisting:
                continue
            case .createdAndLinked:
                createdSiteCount += 1
                continue
            }
            guard createMissingSites else { continue }
            if createSiteForImportNameIfNeeded(
                to: activity,
                catalogSites: &catalogSites,
                modelContext: modelContext
            ) {
                createdSiteCount += 1
            }
        }
        return createdSiteCount
    }

    enum OpenDiveMapSiteLinkOutcome: Equatable, Sendable {
        case noMatch
        case linkedExisting
        case createdAndLinked
    }

    /// Links to an OpenDiveMap reference row — existing tagged catalog site, or a new enriched site.
    @MainActor
    @discardableResult
    static func applyOpenDiveMapSiteLinkIfNeeded(
        to activity: DiveActivity,
        catalogSites: inout [DiveSite],
        modelContext: ModelContext,
        reference: [DiveSiteReferenceSnapshot] = DiveSiteReferenceCatalog.bundledReference(),
        createSiteWhenMissing: Bool = true
    ) -> OpenDiveMapSiteLinkOutcome {
        guard activity.diveSiteID == nil else { return .noMatch }
        guard let match = bestOpenDiveMapReferenceMatch(for: activity, reference: reference) else { return .noMatch }

        if let site = DiveSiteCatalogMatcher.catalogSite(forReferenceID: match.snapshot.id, in: catalogSites) {
            link(activity, to: site, modelContext: modelContext)
            return .linkedExisting
        }
        guard createSiteWhenMissing else { return .noMatch }

        let site = DiveSiteCatalogMatcher.makeDiveSite(from: match.snapshot)
        modelContext.insert(site)
        catalogSites.append(site)
        link(activity, to: site, modelContext: modelContext)
        return .createdAndLinked
    }

    /// Links to an existing catalog row tagged with the matched OpenDiveMap reference id.
    @discardableResult
    static func applyOpenDiveMapReferenceLinkIfNeeded(
        to activity: DiveActivity,
        catalogSites: [DiveSite],
        modelContext: ModelContext? = nil,
        reference: [DiveSiteReferenceSnapshot] = DiveSiteReferenceCatalog.bundledReference()
    ) -> Bool {
        guard activity.diveSiteID == nil else { return false }
        guard let match = bestOpenDiveMapReferenceMatch(for: activity, reference: reference) else { return false }
        guard let site = DiveSiteCatalogMatcher.catalogSite(forReferenceID: match.snapshot.id, in: catalogSites) else {
            return false
        }
        if let modelContext {
            link(activity, to: site, modelContext: modelContext)
        } else {
            link(activity, to: site)
        }
        return true
    }

    /// Creates a catalog **`DiveSite`** from a strong OpenDiveMap reference match (name + coordinates when present).
    @MainActor
    @discardableResult
    static func createSiteFromOpenDiveMapReferenceIfNeeded(
        to activity: DiveActivity,
        catalogSites: inout [DiveSite],
        modelContext: ModelContext,
        reference: [DiveSiteReferenceSnapshot] = DiveSiteReferenceCatalog.bundledReference()
    ) -> Bool {
        switch applyOpenDiveMapSiteLinkIfNeeded(
            to: activity,
            catalogSites: &catalogSites,
            modelContext: modelContext,
            reference: reference,
            createSiteWhenMissing: true
        ) {
        case .createdAndLinked:
            return true
        case .linkedExisting, .noMatch:
            return false
        }
    }

    /// Creates a user-owned **`UserDiveSite`** when the dive has an import **`siteName`** with no exact catalog match.
    @MainActor
    @discardableResult
    static func createSiteForImportNameIfNeeded(
        to activity: DiveActivity,
        catalogSites: inout [DiveSite],
        modelContext: ModelContext
    ) -> Bool {
        guard activity.diveSiteID == nil else { return false }
        guard let siteName = trimmedSiteName(activity.siteName) else { return false }
        guard DiveMapCoordinateResolver.exactMatchingSites(forSiteName: siteName, in: catalogSites).isEmpty else {
            return false
        }

        let places = DiveImportedLocationParsing.placeFields(fromLocationName: activity.locationName)
        let lat = activity.entryCoordinate.flatMap { DiveMapCoordinateResolver.isUsable($0) ? $0.latitude : nil }
        let lon = activity.entryCoordinate.flatMap { DiveMapCoordinateResolver.isUsable($0) ? $0.longitude : nil }
        let site = UserDiveSite(
            siteName: siteName,
            country: DiveSiteFormValidation.sanitizedPlaceField(places.country),
            region: DiveSiteFormValidation.sanitizedPlaceField(places.region),
            latCoords: lat,
            longCoords: lon,
            waterType: .saltwater,
            owner: activity.owner
        )
        modelContext.insert(site)
        link(activity, to: site)
        return true
    }

    private static func trimmedSiteName(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func bestOpenDiveMapReferenceMatch(
        for activity: DiveActivity,
        reference: [DiveSiteReferenceSnapshot]
    ) -> DiveSiteReferenceMatch? {
        guard !reference.isEmpty else { return nil }
        let importName = trimmedSiteName(activity.siteName)
        let coordinate = activity.entryCoordinate.flatMap {
            DiveMapCoordinateResolver.isUsable($0) ? $0 : nil
        }
        guard importName != nil || coordinate != nil else { return nil }
        return DiveSiteCatalogMatcher.bestReferenceMatch(
            importName: importName,
            importCoordinate: coordinate,
            reference: reference,
            minimumScore: DiveSiteCatalogMatcher.autoLinkThreshold
        )
    }

    /// Inserts a user-owned **`UserDiveSite`** without linking a dive (Explore add).
    @discardableResult
    static func createCatalogSite(
        siteName: String,
        country: String = "",
        region: String = "",
        bodyOfWater: String = "",
        latCoords: Double?,
        longCoords: Double?,
        waterType: DiveWaterType = .saltwater,
        owner: UserProfile? = nil,
        modelContext: ModelContext,
        persistImmediately: Bool = true
    ) throws -> UserDiveSite {
        let site = UserDiveSite(
            siteName: siteName,
            country: DiveSiteFormValidation.sanitizedPlaceField(country),
            region: DiveSiteFormValidation.sanitizedPlaceField(region),
            bodyOfWater: DiveSiteFormValidation.sanitizedPlaceField(bodyOfWater),
            latCoords: latCoords,
            longCoords: longCoords,
            waterType: waterType,
            owner: owner
        )
        modelContext.insert(site)
        if persistImmediately {
            try modelContext.save()
        }
        return site
    }

    /// Inserts a user-owned **`UserDiveSite`** and links **`activity`** to it.
    @discardableResult
    static func createSiteAndLink(
        to activity: DiveActivity,
        siteName: String,
        country: String = "",
        region: String = "",
        bodyOfWater: String = "",
        latCoords: Double?,
        longCoords: Double?,
        waterType: DiveWaterType = .saltwater,
        modelContext: ModelContext,
        persistImmediately: Bool = true
    ) throws -> UserDiveSite {
        let site = try createCatalogSite(
            siteName: siteName,
            country: country,
            region: region,
            bodyOfWater: bodyOfWater,
            latCoords: latCoords,
            longCoords: longCoords,
            waterType: waterType,
            owner: activity.owner,
            modelContext: modelContext,
            persistImmediately: false
        )
        link(activity, to: site)
        if persistImmediately {
            try modelContext.save()
        }
        return site
    }

    /// Applies **`DiveSiteFormDraft`** fields onto an existing catalog **`DiveSite`** (name, place, water type, coordinates).
    /// Clears coordinates (and timezone) when the draft has no usable lat/lon pair.
    static func applyCatalogSiteEdits(
        to site: DiveSite,
        draft: DiveSiteFormDraft,
        modelContext: ModelContext,
        persistImmediately: Bool = true
    ) throws {
        try applySiteEdits(to: site, draft: draft, modelContext: modelContext, persistImmediately: persistImmediately)
    }

    /// Applies **`DiveSiteFormDraft`** fields onto a user-owned **`UserDiveSite`**.
    static func applyUserSiteEdits(
        to site: UserDiveSite,
        draft: DiveSiteFormDraft,
        modelContext: ModelContext,
        persistImmediately: Bool = true
    ) throws {
        try applySiteEdits(to: site, draft: draft, modelContext: modelContext, persistImmediately: persistImmediately)
    }

    private static func applySiteEdits(
        to site: DiveSite,
        draft: DiveSiteFormDraft,
        modelContext: ModelContext,
        persistImmediately: Bool
    ) throws {
        guard let siteName = DiveSiteFormValidation.sanitizedSiteName(draft.siteName) else {
            throw DiveActivitySiteAssociationError.missingSiteName
        }

        let previousLat = site.latCoords
        let previousLon = site.longCoords
        let parsed = DiveSiteFormValidation.parsedCoordinate(
            latitudeText: draft.latitudeText,
            longitudeText: draft.longitudeText
        )

        site.siteName = siteName
        site.country = DiveSiteFormValidation.sanitizedPlaceField(draft.country)
        site.region = DiveSiteFormValidation.sanitizedPlaceField(draft.region)
        site.bodyOfWater = DiveSiteFormValidation.sanitizedPlaceField(draft.bodyOfWater)
        site.waterType = draft.waterType
        site.entry = DiveSiteFormValidation.sanitizedPlaceField(draft.entry)
        site.environment = DiveSiteFormValidation.sanitizedPlaceField(draft.environment)
        switch DiveSiteFormValidation.parsedOptionalMaxDepthMeters(draft.maxDepthMetersText) {
        case .none:
            site.maxDepthMeters = nil
        case .value(let meters):
            site.maxDepthMeters = meters
        case .invalid:
            throw DiveActivitySiteAssociationError.invalidMaxDepth
        }
        site.latCoords = parsed?.latitude
        site.longCoords = parsed?.longitude

        let coordsChanged = site.latCoords != previousLat || site.longCoords != previousLon
        if coordsChanged, parsed == nil {
            site.timeZoneIdentifier = nil
            site.timeZoneOffsetSeconds = nil
        }
        site.refreshOwnershipFromSiteTags()

        if persistImmediately {
            try modelContext.save()
        }
    }

    private static func applySiteEdits(
        to site: UserDiveSite,
        draft: DiveSiteFormDraft,
        modelContext: ModelContext,
        persistImmediately: Bool
    ) throws {
        guard let siteName = DiveSiteFormValidation.sanitizedSiteName(draft.siteName) else {
            throw DiveActivitySiteAssociationError.missingSiteName
        }

        let previousLat = site.latCoords
        let previousLon = site.longCoords
        let parsed = DiveSiteFormValidation.parsedCoordinate(
            latitudeText: draft.latitudeText,
            longitudeText: draft.longitudeText
        )

        site.siteName = siteName
        site.country = DiveSiteFormValidation.sanitizedPlaceField(draft.country)
        site.region = DiveSiteFormValidation.sanitizedPlaceField(draft.region)
        site.bodyOfWater = DiveSiteFormValidation.sanitizedPlaceField(draft.bodyOfWater)
        site.waterType = draft.waterType
        site.entry = DiveSiteFormValidation.sanitizedPlaceField(draft.entry)
        site.environment = DiveSiteFormValidation.sanitizedPlaceField(draft.environment)
        switch DiveSiteFormValidation.parsedOptionalMaxDepthMeters(draft.maxDepthMetersText) {
        case .none:
            site.maxDepthMeters = nil
        case .value(let meters):
            site.maxDepthMeters = meters
        case .invalid:
            throw DiveActivitySiteAssociationError.invalidMaxDepth
        }
        site.latCoords = parsed?.latitude
        site.longCoords = parsed?.longitude

        let coordsChanged = site.latCoords != previousLat || site.longCoords != previousLon
        if coordsChanged, parsed == nil {
            site.timeZoneIdentifier = nil
            site.timeZoneOffsetSeconds = nil
        }
        site.updatedAt = Date()

        if persistImmediately {
            try modelContext.save()
        }
    }
}

enum DiveActivitySiteAssociationError: Error, Equatable {
    case missingSiteName
    case invalidMaxDepth
}

extension DiveActivitySiteAssociation {
    struct OpenDiveMapSiteBackfillResult: Equatable, Sendable {
        let linkedActivityCount: Int
        let createdSiteCount: Int
        let enrichedSiteCount: Int
        let hydratedUserSiteCount: Int

        static let empty = OpenDiveMapSiteBackfillResult(
            linkedActivityCount: 0,
            createdSiteCount: 0,
            enrichedSiteCount: 0,
            hydratedUserSiteCount: 0
        )
    }

    /// One-time / idempotent pass: link unlinked dives to OpenDiveMap reference rows and tag local-only catalog sites.
    @MainActor
    @discardableResult
    static func backfillOpenDiveMapSiteLinks(modelContext: ModelContext) throws -> OpenDiveMapSiteBackfillResult {
        let reference = DiveSiteReferenceCatalog.bundledReference()
        guard !reference.isEmpty else { return .empty }

        var catalogSites = try fetchCatalogSites(modelContext: modelContext)
        let activities = try modelContext.fetch(FetchDescriptor<DiveActivity>())

        var enrichedSiteCount = 0
        for site in catalogSites {
            guard DiveSiteCatalogMatcher.enrichCatalogSiteFromOpenDiveMapIfNeeded(
                site,
                catalogSites: catalogSites,
                reference: reference
            ) else { continue }
            enrichedSiteCount += 1
        }

        var linkedActivityCount = 0
        var createdSiteCount = 0
        for activity in activities where activity.diveSiteID == nil {
            switch applyOpenDiveMapSiteLinkIfNeeded(
                to: activity,
                catalogSites: &catalogSites,
                modelContext: modelContext,
                reference: reference,
                createSiteWhenMissing: true
            ) {
            case .noMatch:
                continue
            case .linkedExisting:
                linkedActivityCount += 1
            case .createdAndLinked:
                linkedActivityCount += 1
                createdSiteCount += 1
            }
        }

        let hydratedUserSiteCount = try hydrateSyncedUserDiveSitesForLinkedDives(
            modelContext: modelContext,
            catalogSites: catalogSites,
            reference: reference
        )

        if linkedActivityCount > 0 || createdSiteCount > 0 || enrichedSiteCount > 0 || hydratedUserSiteCount > 0 {
            try modelContext.save()
        }

        return OpenDiveMapSiteBackfillResult(
            linkedActivityCount: linkedActivityCount,
            createdSiteCount: createdSiteCount,
            enrichedSiteCount: enrichedSiteCount,
            hydratedUserSiteCount: hydratedUserSiteCount
        )
    }

    /// Ensures every dive-linked site id has a CloudKit-synced **`UserDiveSite`** (catalog snapshot or OpenDiveMap rematch).
    ///
    /// Heals CloudKit restore / second-device installs where **`DiveActivity.diveSiteID`** survived but the
    /// local-only catalog **`DiveSite`** did not.
    @MainActor
    @discardableResult
    static func hydrateSyncedUserDiveSitesForLinkedDives(
        modelContext: ModelContext,
        catalogSites: [DiveSite]? = nil,
        reference: [DiveSiteReferenceSnapshot] = DiveSiteReferenceCatalog.bundledReference()
    ) throws -> Int {
        let activities = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        let existingUserSites = try modelContext.fetch(FetchDescriptor<UserDiveSite>())
        var userByID: [UUID: UserDiveSite] = [:]
        for site in existingUserSites {
            userByID[site.id] = site
        }
        var catalog = try catalogSites ?? fetchCatalogSites(modelContext: modelContext)
        var catalogByID: [UUID: DiveSite] = [:]
        for site in catalog {
            catalogByID[site.id] = site
        }
        var created = 0

        for activity in activities {
            guard let siteID = activity.diveSiteID else { continue }
            if userByID[siteID] != nil { continue }

            if let catalogSite = catalogByID[siteID] {
                let snapshot = ensureSyncedUserDiveSiteSnapshot(
                    of: catalogSite,
                    owner: activity.owner,
                    modelContext: modelContext
                )
                userByID[siteID] = snapshot
                created += 1
                continue
            }

            guard let match = bestOpenDiveMapReferenceMatch(for: activity, reference: reference) else {
                continue
            }

            if let tagged = DiveSiteCatalogMatcher.catalogSite(
                forReferenceID: match.snapshot.id,
                in: catalog
            ) {
                // Dive still points at an orphan UUID; retarget to the existing tagged catalog row + snapshot.
                link(activity, to: tagged, modelContext: modelContext)
                if userByID[tagged.id] == nil {
                    created += 1
                }
                userByID[tagged.id] = try? DiveLinkedSiteResolver.existingUserDiveSite(
                    id: tagged.id,
                    modelContext: modelContext
                )
                continue
            }

            let userSnapshot = UserDiveSite.snapshot(
                from: match.snapshot,
                id: siteID,
                owner: activity.owner
            )
            modelContext.insert(userSnapshot)
            userByID[siteID] = userSnapshot

            let catalogSite = DiveSiteCatalogMatcher.makeDiveSite(from: match.snapshot, id: siteID)
            modelContext.insert(catalogSite)
            catalog.append(catalogSite)
            catalogByID[siteID] = catalogSite
            created += 1
        }

        return created
    }

    /// Trims or backfills **`siteName`** on OpenDiveMap-tagged catalog rows (idempotent).
    @MainActor
    static func normalizeOpenDiveMapCatalogSiteNames(modelContext: ModelContext) throws {
        let reference = DiveSiteReferenceCatalog.bundledReference()
        guard !reference.isEmpty else { return }

        let catalogSites = try fetchCatalogSites(modelContext: modelContext)
        var changed = false
        for site in catalogSites where DiveSiteCatalogMatcher.referenceID(from: site.siteTags) != nil {
            if DiveSiteCatalogMatcher.normalizeCatalogSiteNameIfNeeded(site, reference: reference) {
                changed = true
            }
            if DiveSiteCatalogMatcher.enrichCatalogSiteMetadataFromReferenceIfNeeded(site, reference: reference) {
                changed = true
            }
        }
        if changed {
            try modelContext.save()
        }
    }

    /// Canonicalizes known country aliases on all catalog **`DiveSite`** rows (idempotent).
    @MainActor
    static func normalizeCatalogSiteCountries(modelContext: ModelContext) throws {
        let catalogSites = try fetchCatalogSites(modelContext: modelContext)
        var changed = false
        for site in catalogSites where DiveSiteCatalogMatcher.normalizeCatalogSiteCountryIfNeeded(site) {
            changed = true
        }
        if changed {
            try modelContext.save()
        }
    }
}
