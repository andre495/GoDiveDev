import Foundation
import SwiftData

/// Surface swim / snorkel session (Garmin FIT import and future manual entry).
@Model
final class SnorkelActivity {

    var id: UUID = UUID()
    var sourceRaw: String = DiveSource.manual.rawValue
    @Transient
    var source: DiveSource {
        get { DiveSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
    var sourceActivityId: String?

    var startTime: Date = Date()
    var timeZoneOffsetSeconds: Int?
    /// Session length for media windows and display (**minutes**, floor from FIT elapsed time).
    var durationMinutes: Int = 0

    var swimDistanceMeters: Double?
    var totalCalories: Int?
    var avgHeartRateBPM: Int?
    var maxHeartRateBPM: Int?
    var avgTemperatureCelsius: Double?
    /// FIT **`enhanced_avg_speed`** (m/s) when present.
    var avgMovingSpeedMetersPerSecond: Double?
    /// Max shallow depth from FIT **`record`** samples (**snorkeling** sport only).
    var maxDepthMeters: Double?

    var siteName: String?
    var locationName: String?
    var entryLatitude: Double?
    var entryLongitude: Double?
    var diveSiteID: UUID?

    var notes: String?

    @Relationship(deleteRule: .cascade)
    var marineLifeSightingsStorage: [SightingInstance]? = []
    @Transient
    var marineLifeSightings: [SightingInstance] {
        get { marineLifeSightingsStorage ?? [] }
        set { marineLifeSightingsStorage = newValue }
    }

    @Relationship(deleteRule: .cascade)
    var mediaBuddyTagsStorage: [DiveMediaBuddyTag]? = []
    @Transient
    var mediaBuddyTags: [DiveMediaBuddyTag] {
        get { mediaBuddyTagsStorage ?? [] }
        set { mediaBuddyTagsStorage = newValue }
    }

    @Relationship(deleteRule: .cascade)
    var buddiesStorage: [SnorkelBuddyTag]? = []
    @Transient
    var buddies: [SnorkelBuddyTag] {
        get { buddiesStorage ?? [] }
        set { buddiesStorage = newValue }
    }

    @Relationship(deleteRule: .cascade)
    var mediaPhotosStorage: [SnorkelMediaPhoto]? = []
    @Transient
    var mediaPhotos: [SnorkelMediaPhoto] {
        get { mediaPhotosStorage ?? [] }
        set { mediaPhotosStorage = newValue }
    }

    var featuredMediaPhotoID: UUID?

    @Transient
    var profilePoints: [SnorkelProfilePoint] = []

    /// Compressed GPS + heart-rate track for CloudKit sync (**`SnorkelSwimTrackCodec`**, LZFSE).
    /// Local chart/map rows live in **`GoDiveUserLocal`**; this blob mirrors across devices.
    var swimTrackData: Data?

    /// Frozen WeatherKit snapshot captured at import (**`ActivityWeatherPersistedSnapshot`** JSON envelope).
    var activityWeatherSnapshotData: Data?

    var ownerProfileID: UUID?
    @Relationship
    var owner: UserProfile?

    var rawImportVersion: String?

    init(
        id: UUID = UUID(),
        source: DiveSource = .manual,
        sourceActivityId: String? = nil,
        startTime: Date,
        timeZoneOffsetSeconds: Int? = nil,
        durationMinutes: Int = 0,
        swimDistanceMeters: Double? = nil,
        totalCalories: Int? = nil,
        avgHeartRateBPM: Int? = nil,
        maxHeartRateBPM: Int? = nil,
        avgTemperatureCelsius: Double? = nil,
        avgMovingSpeedMetersPerSecond: Double? = nil,
        maxDepthMeters: Double? = nil,
        entryCoordinate: DiveCoordinate? = nil,
        rawImportVersion: String? = nil
    ) {
        self.id = id
        self.source = source
        self.sourceActivityId = sourceActivityId
        self.startTime = startTime
        self.timeZoneOffsetSeconds = timeZoneOffsetSeconds
        self.durationMinutes = durationMinutes
        self.swimDistanceMeters = swimDistanceMeters
        self.totalCalories = totalCalories
        self.avgHeartRateBPM = avgHeartRateBPM
        self.maxHeartRateBPM = maxHeartRateBPM
        self.avgTemperatureCelsius = avgTemperatureCelsius
        self.avgMovingSpeedMetersPerSecond = avgMovingSpeedMetersPerSecond
        self.maxDepthMeters = maxDepthMeters
        self.entryCoordinate = entryCoordinate
        self.rawImportVersion = rawImportVersion
    }
}

extension SnorkelActivity: DiveSiteLinkableActivity {}

extension SnorkelActivity {
    @Transient
    var entryCoordinate: DiveCoordinate? {
        get {
            guard let entryLatitude, let entryLongitude else { return nil }
            return DiveCoordinate(latitude: entryLatitude, longitude: entryLongitude)
        }
        set {
            entryLatitude = newValue?.latitude
            entryLongitude = newValue?.longitude
        }
    }

    var resolvedLinkedSite: DiveLinkedSiteResolver.ResolvedSite? {
        guard let diveSiteID, let modelContext else { return nil }
        return try? DiveLinkedSiteResolver.resolve(id: diveSiteID, modelContext: modelContext)
    }

    func formattedStartDateTime() -> String {
        DiveActivityTimePresentation.formatDateTime(startTime, timeZoneOffsetSeconds: timeZoneOffsetSeconds)
    }

    func formattedStartDateOnly() -> String {
        DiveActivityTimePresentation.formatDateOnly(startTime, timeZoneOffsetSeconds: timeZoneOffsetSeconds)
    }

    /// Primary site title: linked catalog name, else import **`siteName`**.
    var resolvedSiteName: String? {
        if let site = resolvedLinkedSite, let linked = DiveSiteCatalogMatcher.resolvedCatalogSiteName(for: site) {
            return linked
        }
        let imported = siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return imported.isEmpty ? nil : imported
    }

    var bottomTimeSeconds: Int? { nil }

    /// Catalog **`DiveSite`** coordinates when linked and usable.
    var siteCoordinate: DiveCoordinate? {
        guard let site = resolvedLinkedSite else { return nil }
        return DiveMapCoordinateResolver.coordinate(from: site)
    }

    /// Coordinate for map pin: linked site, entry GPS, then name lookup.
    func resolvedMapCoordinate(catalogSites: [DiveSite]) -> DiveCoordinate? {
        if let diveSiteID,
           let matched = catalogSites.first(where: { $0.id == diveSiteID }),
           let coordinate = DiveMapCoordinateResolver.coordinate(from: matched),
           DiveMapCoordinateResolver.isUsable(coordinate) {
            return coordinate
        }
        if let siteCoordinate {
            return siteCoordinate
        }
        if let entry = entryCoordinate, DiveMapCoordinateResolver.isUsable(entry) {
            return entry
        }
        return DiveMapCoordinateResolver.coordinate(
            fromSiteName: siteName,
            in: catalogSites
        )
    }
}
