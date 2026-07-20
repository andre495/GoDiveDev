import Foundation
import SwiftData

/// When a dive has location hints but no linked **`DiveSite`**, offers creating a catalog site from the map tab.
enum DiveActivityMapSitePrompt {
    static let dialogTitle = "No existing dive site found."
    static let dialogMessage = "Add new site?"

    /// **`true`** when the dive is unlinked and has import **`entryCoordinate`** and/or **`siteName`**.
    nonisolated static func isEligible(for activity: DiveActivity) -> Bool {
        activity.diveSiteID == nil && hasLocationHint(activity)
    }

    nonisolated static func hasLocationHint(_ activity: DiveActivity) -> Bool {
        if let entry = activity.entryCoordinate, DiveMapCoordinateResolver.isUsable(entry) {
            return true
        }
        let name = activity.siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !name.isEmpty
    }

    nonisolated static func shouldPresentAutomatically(
        for activity: DiveActivity,
        userDeclined: Bool
    ) -> Bool {
        isEligible(for: activity) && !userDeclined
    }

    nonisolated static func showsInfoButton(
        for activity: DiveActivity,
        userDeclined: Bool
    ) -> Bool {
        isEligible(for: activity) && userDeclined
    }

    /// Prepopulates the add/edit site sheet from import fields and optional linked **`catalogSite`**.
    nonisolated static func draft(
        from activity: DiveActivity,
        catalogSite: DiveLinkedSiteResolver.ResolvedSite? = nil
    ) -> DiveSiteFormDraft {
        let importedPlace = DiveImportedLocationParsing.placeFields(fromLocationName: activity.locationName)

        let siteName: String = {
            if let site = catalogSite {
                let catalog = site.siteName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !catalog.isEmpty { return catalog }
            }
            return activity.siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }()

        let country = nonEmptyPlaceField(catalogSite?.country) ?? importedPlace.country
        let region = nonEmptyPlaceField(catalogSite?.region) ?? importedPlace.region
        let bodyOfWater = nonEmptyPlaceField(catalogSite?.bodyOfWater) ?? ""

        let coordinate = catalogCoordinate(catalogSite) ?? activity.entryCoordinate
        let latitude = coordinate.map { String(format: "%.5f", $0.latitude) } ?? ""
        let longitude = coordinate.map { String(format: "%.5f", $0.longitude) } ?? ""

        return DiveSiteFormDraft(
            siteName: siteName,
            country: country,
            region: region,
            bodyOfWater: bodyOfWater,
            latitudeText: latitude,
            longitudeText: longitude,
            waterType: catalogSite?.resolvedWaterType ?? .saltwater
        )
    }

    private nonisolated static func nonEmptyPlaceField(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private nonisolated static func catalogCoordinate(_ site: DiveLinkedSiteResolver.ResolvedSite?) -> DiveCoordinate? {
        guard let site else { return nil }
        return DiveMapCoordinateResolver.coordinate(from: site)
    }
}

/// UserDefaults flag: user chose **Not now** on the map-tab site prompt (per dive).
enum DiveActivityMapSitePromptStorage {
    private nonisolated static let keyPrefix = "goDiveDeclinedMapSitePrompt."

    nonisolated static func isDeclined(activityID: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: keyPrefix + activityID.uuidString)
    }

    nonisolated static func setDeclined(activityID: UUID, declined: Bool) {
        let key = keyPrefix + activityID.uuidString
        if declined {
            UserDefaults.standard.set(true, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

struct DiveSiteFormDraft: Equatable, Sendable {
    var siteName: String
    var country: String
    var region: String
    var bodyOfWater: String
    var latitudeText: String
    var longitudeText: String
    var waterType: DiveWaterType = .saltwater
    var entry: String = ""
    var environment: String = ""
    var maxDepthMetersText: String = ""

    /// Prefills the edit sheet from an existing catalog **`DiveSite`**.
    nonisolated init(from site: DiveSite) {
        let coordinate = DiveMapCoordinateResolver.coordinate(from: site)
        self.siteName = site.siteName
        self.country = site.country
        self.region = site.region
        self.bodyOfWater = site.bodyOfWater
        self.latitudeText = coordinate.map { String(format: "%.5f", $0.latitude) } ?? ""
        self.longitudeText = coordinate.map { String(format: "%.5f", $0.longitude) } ?? ""
        self.waterType = site.resolvedWaterType
        self.entry = site.entry
        self.environment = site.environment
        self.maxDepthMetersText = site.maxDepthMeters.map(String.init) ?? ""
    }

    /// Prefills the edit sheet from a user-owned **`UserDiveSite`**.
    nonisolated init(from site: UserDiveSite) {
        let coordinate = DiveMapCoordinateResolver.coordinate(from: site)
        self.siteName = site.siteName
        self.country = site.country
        self.region = site.region
        self.bodyOfWater = site.bodyOfWater
        self.latitudeText = coordinate.map { String(format: "%.5f", $0.latitude) } ?? ""
        self.longitudeText = coordinate.map { String(format: "%.5f", $0.longitude) } ?? ""
        self.waterType = site.resolvedWaterType
        self.entry = site.entry
        self.environment = site.environment
        self.maxDepthMetersText = site.maxDepthMeters.map(String.init) ?? ""
    }

    nonisolated init(
        siteName: String,
        country: String,
        region: String,
        bodyOfWater: String,
        latitudeText: String,
        longitudeText: String,
        waterType: DiveWaterType = .saltwater,
        entry: String = "",
        environment: String = "",
        maxDepthMetersText: String = ""
    ) {
        self.siteName = siteName
        self.country = country
        self.region = region
        self.bodyOfWater = bodyOfWater
        self.latitudeText = latitudeText
        self.longitudeText = longitudeText
        self.waterType = waterType
        self.entry = entry
        self.environment = environment
        self.maxDepthMetersText = maxDepthMetersText
    }
}

enum DiveSiteFormValidation: Sendable {
    nonisolated static func sanitizedSiteName(_ raw: String) -> String? {
        GoDiveInputSanitization.sanitizedOptionalText(
            raw,
            maxLength: GoDiveInputSanitization.maxSiteNameLength
        )
    }

    /// Trims whitespace; returns `""` when empty (optional hierarchy fields on the add-site form).
    nonisolated static func sanitizedPlaceField(_ raw: String) -> String {
        GoDiveInputSanitization.trimmedAndCapped(
            raw,
            maxLength: GoDiveInputSanitization.maxPlaceFieldLength
        )
    }

    nonisolated static func trimmedNonEmpty(_ raw: String) -> String? {
        GoDiveInputSanitization.sanitizedOptionalText(
            raw,
            maxLength: GoDiveInputSanitization.maxSiteNameLength
        )
    }

    nonisolated static func parsedCoordinate(latitudeText: String, longitudeText: String) -> DiveCoordinate? {
        let latRaw = latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lonRaw = longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !latRaw.isEmpty, !lonRaw.isEmpty else { return nil }
        guard let lat = Double(latRaw), let lon = Double(lonRaw) else { return nil }
        let candidate = DiveCoordinate(latitude: lat, longitude: lon)
        return DiveMapCoordinateResolver.isUsable(candidate) ? candidate : nil
    }

    nonisolated static func canSave(draft: DiveSiteFormDraft) -> Bool {
        guard sanitizedSiteName(draft.siteName) != nil else { return false }
        switch parsedOptionalMaxDepthMeters(draft.maxDepthMetersText) {
        case .invalid:
            return false
        case .none, .value:
            return true
        }
    }

    /// Parses optional max-depth meters text. Empty → **`.none`**; valid int ≥ 0 → **`.value`**; otherwise **`.invalid`**.
    nonisolated static func parsedOptionalMaxDepthMeters(_ raw: String) -> DiveSiteFormOptionalIntParseResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .none }
        guard let value = Int(trimmed), value >= 0 else { return .invalid }
        return .value(value)
    }
}

/// Optional integer parse result for dive-site form fields (file-scoped for nonisolated Equatable).
nonisolated enum DiveSiteFormOptionalIntParseResult: Equatable, Sendable {
    case none
    case value(Int)
    case invalid
}
