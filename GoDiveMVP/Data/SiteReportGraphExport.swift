import Foundation
import SwiftData

/// Anonymized site-visit report for the community ontology graph (1:1 with an activity).
/// No uid / profile / media / GPS / site name.
nonisolated struct SiteReportGraphExportPayload: Equatable, Sendable, Codable {
    var contributionId: String
    var activityKind: String
    var odmSiteId: String?
    var diveSiteCatalogUUID: String?
    var waterBody: String?
    var country: String?
    var region: String?
    var reportedMaxDepthM: Double?
    var reportedCurrent: String?
    var reportedVisibility: String?
    var reportedWaterTempC: Double?
    var reportedWaterType: String?
    var reportDate: String
    var timeOfDay: String
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

/// Builds anonymized **SiteReport** payloads from local dive / snorkel activities.
nonisolated enum SiteReportGraphExport: Sendable {
    static let schemaVersion = 1

    nonisolated static func payload(
        contributionId: String,
        activityKind: SiteReportGraphExportPayload.ActivityKind,
        startTime: Date,
        diveSiteID: UUID?,
        timeZoneOffsetSeconds: Int?,
        maxDepthMeters: Double?,
        currentStrengthRaw: String?,
        visibilityRaw: String?,
        waterTempCelsius: Double?,
        waterTypeRaw: String?,
        catalogSites: [DiveSite],
        userSites: [UserDiveSite] = [],
        status: SiteReportGraphExportPayload.Status = .active
    ) -> SiteReportGraphExportPayload? {
        guard !contributionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let site = SightingGraphExport.siteContext(
            diveSiteID: diveSiteID,
            catalogSites: catalogSites,
            userSites: userSites
        )
        let tz = timeZoneOffsetSeconds ?? site.timeZoneOffsetSeconds
        let depth: Double?
        if let maxDepthMeters, maxDepthMeters > 0 {
            depth = maxDepthMeters
        } else {
            depth = nil
        }

        return SiteReportGraphExportPayload(
            contributionId: contributionId,
            activityKind: activityKind.rawValue,
            odmSiteId: site.odmSiteId,
            diveSiteCatalogUUID: site.diveSiteCatalogUUID,
            waterBody: site.waterBody,
            country: site.country,
            region: site.region,
            reportedMaxDepthM: depth,
            reportedCurrent: SightingGraphExport.trimmedPlace(currentStrengthRaw),
            reportedVisibility: SightingGraphExport.trimmedPlace(visibilityRaw),
            reportedWaterTempC: waterTempCelsius,
            reportedWaterType: SightingGraphExport.trimmedPlace(waterTypeRaw),
            reportDate: SightingGraphExport.sightingDateString(
                from: startTime,
                timeZoneOffsetSeconds: tz
            ),
            timeOfDay: SightingGraphExport.timeOfDay(
                from: startTime,
                timeZoneOffsetSeconds: tz
            ),
            status: status.rawValue,
            schemaVersion: schemaVersion
        )
    }

    nonisolated static func payload(
        from dive: DiveActivity,
        contributionId: String,
        catalogSites: [DiveSite],
        userSites: [UserDiveSite] = [],
        status: SiteReportGraphExportPayload.Status = .active
    ) -> SiteReportGraphExportPayload? {
        payload(
            contributionId: contributionId,
            activityKind: .dive,
            startTime: dive.startTime,
            diveSiteID: dive.diveSiteID,
            timeZoneOffsetSeconds: dive.timeZoneOffsetSeconds,
            maxDepthMeters: dive.maxDepthMeters,
            currentStrengthRaw: dive.diveCurrentStrength?.rawValue,
            visibilityRaw: dive.diveVisibility?.rawValue,
            waterTempCelsius: dive.waterTempAvgCelsius,
            waterTypeRaw: dive.diveWaterType?.rawValue ?? dive.resolvedDiveWaterType.rawValue,
            catalogSites: catalogSites,
            userSites: userSites,
            status: status
        )
    }

    nonisolated static func payload(
        from snorkel: SnorkelActivity,
        contributionId: String,
        catalogSites: [DiveSite],
        userSites: [UserDiveSite] = [],
        status: SiteReportGraphExportPayload.Status = .active
    ) -> SiteReportGraphExportPayload? {
        payload(
            contributionId: contributionId,
            activityKind: .snorkel,
            startTime: snorkel.startTime,
            diveSiteID: snorkel.diveSiteID,
            timeZoneOffsetSeconds: snorkel.timeZoneOffsetSeconds,
            maxDepthMeters: snorkel.maxDepthMeters,
            currentStrengthRaw: nil,
            visibilityRaw: nil,
            waterTempCelsius: snorkel.avgTemperatureCelsius,
            waterTypeRaw: nil,
            catalogSites: catalogSites,
            userSites: userSites,
            status: status
        )
    }

    nonisolated static func firestoreFields(from payload: SiteReportGraphExportPayload) -> [String: Any] {
        var fields: [String: Any] = [
            "contributionId": payload.contributionId,
            "activityKind": payload.activityKind,
            "reportDate": payload.reportDate,
            "timeOfDay": payload.timeOfDay,
            "status": payload.status,
            "schemaVersion": payload.schemaVersion,
            "kind": "siteReport",
        ]
        if let odmSiteId = payload.odmSiteId { fields["odmSiteId"] = odmSiteId }
        if let diveSiteCatalogUUID = payload.diveSiteCatalogUUID {
            fields["diveSiteCatalogUUID"] = diveSiteCatalogUUID
        }
        if let waterBody = payload.waterBody { fields["waterBody"] = waterBody }
        if let country = payload.country { fields["country"] = country }
        if let region = payload.region { fields["region"] = region }
        if let reportedMaxDepthM = payload.reportedMaxDepthM {
            fields["reportedMaxDepthM"] = reportedMaxDepthM
        }
        if let reportedCurrent = payload.reportedCurrent {
            fields["reportedCurrent"] = reportedCurrent
        }
        if let reportedVisibility = payload.reportedVisibility {
            fields["reportedVisibility"] = reportedVisibility
        }
        if let reportedWaterTempC = payload.reportedWaterTempC {
            fields["reportedWaterTempC"] = reportedWaterTempC
        }
        if let reportedWaterType = payload.reportedWaterType {
            fields["reportedWaterType"] = reportedWaterType
        }
        return fields
    }
}
