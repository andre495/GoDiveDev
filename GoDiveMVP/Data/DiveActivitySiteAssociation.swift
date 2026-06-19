import Foundation
import SwiftData

/// Links imported **`DiveActivity`** rows to catalog **`DiveSite`** rows (exact import **`siteName`** first; GPS only when the dive has no site name).
enum DiveActivitySiteAssociation {
    static func fetchCatalogSites(modelContext: ModelContext) throws -> [DiveSite] {
        try modelContext.fetch(FetchDescriptor<DiveSite>())
    }

    /// Tries to set **`diveSite`** / **`diveSiteID`** when not already linked.
    static func applyBestMatch(to activity: DiveActivity, catalogSites: [DiveSite]) {
        guard activity.diveSite == nil else { return }
        guard let site = previewBestMatch(for: activity, catalogSites: catalogSites) else { return }
        link(activity, to: site)
        let reference = DiveSiteReferenceCatalog.bundledReference()
        _ = DiveSiteCatalogMatcher.enrichCatalogSiteFromOpenDiveMapIfNeeded(
            site,
            catalogSites: catalogSites,
            reference: reference
        )
    }

    /// Same rules as **`applyBestMatch`**, without mutating **`diveSite`** (import datetime / timezone lookup).
    static func previewBestMatch(for activity: DiveActivity, catalogSites: [DiveSite]) -> DiveSite? {
        guard activity.diveSite == nil else { return activity.diveSite }

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
        guard activity.diveSite == nil else { return activity.diveSite }
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
        activity.diveSite = site
        activity.diveSiteID = site.id
        DiveActivityDiverWeightDefaults.applyInheritedDefaults(to: activity)
    }

    static func unlink(_ activity: DiveActivity) {
        activity.diveSite = nil
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
            applyBestMatch(to: activity, catalogSites: catalogSites)
            guard activity.diveSite == nil else { continue }
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
        guard activity.diveSite == nil else { return .noMatch }
        guard let match = bestOpenDiveMapReferenceMatch(for: activity, reference: reference) else { return .noMatch }

        if let site = DiveSiteCatalogMatcher.catalogSite(forReferenceID: match.snapshot.id, in: catalogSites) {
            link(activity, to: site)
            return .linkedExisting
        }
        guard createSiteWhenMissing else { return .noMatch }

        let site = DiveSiteCatalogMatcher.makeDiveSite(from: match.snapshot)
        modelContext.insert(site)
        catalogSites.append(site)
        link(activity, to: site)
        return .createdAndLinked
    }

    /// Links to an existing catalog row tagged with the matched OpenDiveMap reference id.
    @discardableResult
    static func applyOpenDiveMapReferenceLinkIfNeeded(
        to activity: DiveActivity,
        catalogSites: [DiveSite],
        reference: [DiveSiteReferenceSnapshot] = DiveSiteReferenceCatalog.bundledReference()
    ) -> Bool {
        guard activity.diveSite == nil else { return false }
        guard let match = bestOpenDiveMapReferenceMatch(for: activity, reference: reference) else { return false }
        guard let site = DiveSiteCatalogMatcher.catalogSite(forReferenceID: match.snapshot.id, in: catalogSites) else {
            return false
        }
        link(activity, to: site)
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

    /// Creates a catalog **`DiveSite`** when the dive has an import **`siteName`** with no exact catalog match.
    @MainActor
    @discardableResult
    static func createSiteForImportNameIfNeeded(
        to activity: DiveActivity,
        catalogSites: inout [DiveSite],
        modelContext: ModelContext
    ) -> Bool {
        guard activity.diveSite == nil else { return false }
        guard let siteName = trimmedSiteName(activity.siteName) else { return false }
        guard DiveMapCoordinateResolver.exactMatchingSites(forSiteName: siteName, in: catalogSites).isEmpty else {
            return false
        }

        let places = DiveImportedLocationParsing.placeFields(fromLocationName: activity.locationName)
        let lat = activity.entryCoordinate.flatMap { DiveMapCoordinateResolver.isUsable($0) ? $0.latitude : nil }
        let lon = activity.entryCoordinate.flatMap { DiveMapCoordinateResolver.isUsable($0) ? $0.longitude : nil }
        let site = DiveSite(
            siteName: siteName,
            country: DiveSiteFormValidation.sanitizedPlaceField(places.country),
            region: DiveSiteFormValidation.sanitizedPlaceField(places.region),
            latCoords: lat,
            longCoords: lon,
            waterType: .saltwater
        )
        modelContext.insert(site)
        catalogSites.append(site)
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

    /// Inserts a catalog **`DiveSite`** and links **`activity`** to it.
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
    ) throws -> DiveSite {
        let site = DiveSite(
            siteName: siteName,
            country: DiveSiteFormValidation.sanitizedPlaceField(country),
            region: DiveSiteFormValidation.sanitizedPlaceField(region),
            bodyOfWater: DiveSiteFormValidation.sanitizedPlaceField(bodyOfWater),
            latCoords: latCoords,
            longCoords: longCoords,
            waterType: waterType
        )
        modelContext.insert(site)
        link(activity, to: site)
        if persistImmediately {
            try modelContext.save()
        }
        return site
    }
}

extension DiveActivitySiteAssociation {
    struct OpenDiveMapSiteBackfillResult: Equatable, Sendable {
        let linkedActivityCount: Int
        let createdSiteCount: Int
        let enrichedSiteCount: Int

        static let empty = OpenDiveMapSiteBackfillResult(
            linkedActivityCount: 0,
            createdSiteCount: 0,
            enrichedSiteCount: 0
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
        for activity in activities where activity.diveSite == nil {
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

        if linkedActivityCount > 0 || createdSiteCount > 0 || enrichedSiteCount > 0 {
            try modelContext.save()
        }

        return OpenDiveMapSiteBackfillResult(
            linkedActivityCount: linkedActivityCount,
            createdSiteCount: createdSiteCount,
            enrichedSiteCount: enrichedSiteCount
        )
    }
}
