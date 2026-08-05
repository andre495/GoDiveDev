import Foundation
import SwiftData

/// Anonymized sighting fact for the community ontology graph (no uid / profile / media / GPS).
nonisolated struct SightingGraphExportPayload: Equatable, Sendable, Codable {
    var contributionId: String
    /// Opaque SiteReport contribution id for the parent activity (1:1 with dive/snorkel).
    var siteReportId: String?
    var marineLifeUUID: String
    var odmSiteId: String?
    var diveSiteCatalogUUID: String?
    var waterBody: String?
    var country: String?
    var region: String?
    var sightingDepthM: Double?
    var timeOfDay: String
    var sightingDate: String
    var activityKind: String
    var status: String
    var schemaVersion: Int

    enum Status: String, Sendable {
        case active
        case deleted
    }

    enum ActivityKind: String, Sendable {
        case dive
        case snorkel
    }
}

/// Builds anonymized community contribution payloads from local **`SightingInstance`** rows.
nonisolated enum SightingGraphExport: Sendable {
    /// Includes country / region + local time-of-day / date bucketing + **`siteReportId`**.
    static let schemaVersion = 3

    /// Coarse geography + stable site ids for the community graph (no lat/lon / site name).
    struct SiteContext: Equatable, Sendable {
        var odmSiteId: String?
        var diveSiteCatalogUUID: String?
        var waterBody: String?
        var country: String?
        var region: String?
        var timeZoneOffsetSeconds: Int?
    }

    /// Activity join used when the sighting row itself lacks site / timezone.
    struct ActivityContext: Equatable, Sendable {
        var diveSiteID: UUID?
        var timeZoneOffsetSeconds: Int?
    }

    /// UTC calendar date `yyyy-MM-dd`, or local civil date when an offset is provided.
    nonisolated static func sightingDateString(
        from date: Date,
        timeZoneOffsetSeconds: Int? = nil,
        calendar: Calendar = .init(identifier: .gregorian)
    ) -> String {
        var cal = calendar
        cal.timeZone = resolvedTimeZone(offsetSeconds: timeZoneOffsetSeconds)
        let parts = cal.dateComponents([.year, .month, .day], from: date)
        let y = parts.year ?? 1970
        let m = parts.month ?? 1
        let d = parts.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    /// Coarse time-of-day bucket from local hour when offset is known; otherwise UTC hour.
    nonisolated static func timeOfDay(
        from date: Date,
        timeZoneOffsetSeconds: Int? = nil,
        calendar: Calendar = .init(identifier: .gregorian)
    ) -> String {
        var cal = calendar
        cal.timeZone = resolvedTimeZone(offsetSeconds: timeZoneOffsetSeconds)
        let hour = cal.component(.hour, from: date)
        switch hour {
        case 5 ... 7, 17 ... 19:
            return "crepuscular"
        case 8 ... 16:
            return "day"
        default:
            return "night"
        }
    }

    nonisolated static func resolvedTimeZone(offsetSeconds: Int?) -> TimeZone {
        DiveActivityTimePresentation.resolvedTimeZone(forOffsetSeconds: offsetSeconds)
    }

    nonisolated static func trimmedPlace(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated static func siteContext(from site: DiveSite) -> SiteContext {
        let odm = DiveSiteCatalogMatcher.referenceID(from: site.siteTags)
        return SiteContext(
            odmSiteId: odm,
            diveSiteCatalogUUID: site.id.uuidString.lowercased(),
            waterBody: trimmedPlace(site.bodyOfWater),
            country: trimmedPlace(site.country),
            region: trimmedPlace(site.region),
            timeZoneOffsetSeconds: site.timeZoneOffsetSeconds
        )
    }

    nonisolated static func siteContext(from site: UserDiveSite) -> SiteContext {
        let odmFromField = trimmedPlace(site.openDiveMapReferenceID)?.lowercased()
        let odmFromTags = DiveSiteCatalogMatcher.referenceID(from: site.siteTags)
        let catalogUUID = (site.catalogDiveSiteID ?? site.id).uuidString.lowercased()
        return SiteContext(
            odmSiteId: odmFromField ?? odmFromTags,
            diveSiteCatalogUUID: catalogUUID,
            waterBody: trimmedPlace(site.bodyOfWater),
            country: trimmedPlace(site.country),
            region: trimmedPlace(site.region),
            timeZoneOffsetSeconds: site.timeZoneOffsetSeconds
        )
    }

    nonisolated static func siteContext(
        diveSiteID: UUID?,
        catalogSites: [DiveSite],
        userSites: [UserDiveSite] = []
    ) -> SiteContext {
        guard let diveSiteID else { return SiteContext() }
        if let catalog = catalogSites.first(where: { $0.id == diveSiteID }) {
            return siteContext(from: catalog)
        }
        if let user = userSites.first(where: { $0.id == diveSiteID }) {
            return siteContext(from: user)
        }
        return SiteContext()
    }

    /// Prefer sighting site, then activity site; timezone prefers activity, then site.
    nonisolated static func resolvedSiteID(
        sightingDiveSiteID: UUID?,
        activity: ActivityContext?
    ) -> UUID? {
        sightingDiveSiteID ?? activity?.diveSiteID
    }

    nonisolated static func resolvedTimeZoneOffsetSeconds(
        activity: ActivityContext?,
        site: SiteContext
    ) -> Int? {
        activity?.timeZoneOffsetSeconds ?? site.timeZoneOffsetSeconds
    }

    nonisolated static func payload(
        sightingUUID: String,
        contributionId: String,
        marineLifeUUID: String,
        sightingDateTime: Date,
        diveActivityID: UUID?,
        snorkelActivityID: UUID?,
        diveSiteID: UUID?,
        sightingDepthMeters: Double?,
        catalogSites: [DiveSite],
        userSites: [UserDiveSite] = [],
        activity: ActivityContext? = nil,
        siteReportId: String? = nil,
        status: SightingGraphExportPayload.Status = .active
    ) -> SightingGraphExportPayload? {
        let trimmedSpecies = marineLifeUUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSpecies.isEmpty else { return nil }
        guard !contributionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let kind: SightingGraphExportPayload.ActivityKind
        if diveActivityID != nil {
            kind = .dive
        } else if snorkelActivityID != nil {
            kind = .snorkel
        } else {
            return nil
        }

        let siteID = resolvedSiteID(sightingDiveSiteID: diveSiteID, activity: activity)
        let site = siteContext(
            diveSiteID: siteID,
            catalogSites: catalogSites,
            userSites: userSites
        )
        let tzOffset = resolvedTimeZoneOffsetSeconds(activity: activity, site: site)
        let depth: Double?
        if let sightingDepthMeters, sightingDepthMeters > 0 {
            depth = sightingDepthMeters
        } else {
            depth = nil
        }

        let trimmedReportId = siteReportId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedReportId = (trimmedReportId?.isEmpty == false) ? trimmedReportId : nil

        return SightingGraphExportPayload(
            contributionId: contributionId,
            siteReportId: resolvedReportId,
            marineLifeUUID: trimmedSpecies,
            odmSiteId: site.odmSiteId,
            diveSiteCatalogUUID: site.diveSiteCatalogUUID,
            waterBody: site.waterBody,
            country: site.country,
            region: site.region,
            sightingDepthM: depth,
            timeOfDay: timeOfDay(from: sightingDateTime, timeZoneOffsetSeconds: tzOffset),
            sightingDate: sightingDateString(from: sightingDateTime, timeZoneOffsetSeconds: tzOffset),
            activityKind: kind.rawValue,
            status: status.rawValue,
            schemaVersion: schemaVersion
        )
    }

    nonisolated static func payload(
        from sighting: SightingInstance,
        contributionId: String,
        catalogSites: [DiveSite],
        userSites: [UserDiveSite] = [],
        activity: ActivityContext? = nil,
        siteReportId: String? = nil,
        status: SightingGraphExportPayload.Status = .active
    ) -> SightingGraphExportPayload? {
        payload(
            sightingUUID: sighting.sightingUUID,
            contributionId: contributionId,
            marineLifeUUID: sighting.marineLifeUUID,
            sightingDateTime: sighting.sightingDateTime,
            diveActivityID: sighting.diveActivityID,
            snorkelActivityID: sighting.snorkelActivityID,
            diveSiteID: sighting.diveSiteID,
            sightingDepthMeters: sighting.sightingDepthMeters,
            catalogSites: catalogSites,
            userSites: userSites,
            activity: activity,
            siteReportId: siteReportId,
            status: status
        )
    }

    /// Firestore document fields (never include sightingUUID / uid / profile / GPS / site name).
    nonisolated static func firestoreFields(from payload: SightingGraphExportPayload) -> [String: Any] {
        var fields: [String: Any] = [
            "contributionId": payload.contributionId,
            "marineLifeUUID": payload.marineLifeUUID,
            "timeOfDay": payload.timeOfDay,
            "sightingDate": payload.sightingDate,
            "activityKind": payload.activityKind,
            "status": payload.status,
            "schemaVersion": payload.schemaVersion,
        ]
        if let siteReportId = payload.siteReportId { fields["siteReportId"] = siteReportId }
        if let odmSiteId = payload.odmSiteId { fields["odmSiteId"] = odmSiteId }
        if let diveSiteCatalogUUID = payload.diveSiteCatalogUUID {
            fields["diveSiteCatalogUUID"] = diveSiteCatalogUUID
        }
        if let waterBody = payload.waterBody { fields["waterBody"] = waterBody }
        if let country = payload.country { fields["country"] = country }
        if let region = payload.region { fields["region"] = region }
        if let sightingDepthM = payload.sightingDepthM { fields["sightingDepthM"] = sightingDepthM }
        return fields
    }
}
