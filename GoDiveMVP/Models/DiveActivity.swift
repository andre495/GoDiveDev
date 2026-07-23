import Foundation
import SwiftData

// MARK: - DiveActivity

/// **Canonical storage (import / SwiftData):** depth fields in **meters**, water temps in **°C**, ascent in **m/s**,
/// cylinder pressures in **psi** (FIT bar and UDDF Pa are converted on import). **`tankVolumeDescription`** stores the
/// **`DiveActivityTankDefaults`** / **Settings → Default tank** for volume + material on import; volume UI follows current default.
/// **Settings → Imperial units** only changes **on-screen** formatting — stored numeric fields are not rewritten.
@Model
final class DiveActivity {

    // Core Identity
    var id: UUID = UUID()
    /// Import / entry origin raw value — CloudKit-safe `String` (was stored `DiveSource` enum).
    @Attribute(originalName: "deviceSource")
    var sourceRaw: String = DiveSource.manual.rawValue
    /// Import / entry origin (Garmin, MacDive, manual).
    @Transient
    var source: DiveSource {
        get { DiveSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
    var sourceDiveId: String?

    // Core Dive Data
    /// Dive start instant (UTC). Display via **`formattedStartDateTime()`** using **`timeZoneOffsetSeconds`** when set.
    var startTime: Date = Date()
    /// Seconds east of UTC for dive-local display (from UDDF **`timezone`**, **`Z`**, or **`±HH:MM`** on import).
    var timeZoneOffsetSeconds: Int?
    var durationMinutes: Int = 0
    var maxDepthMeters: Double = 0
    var averageDepthMeters: Double?

    // Dive Metrics
    var bottomTimeSeconds: Int?
    var surfaceIntervalSeconds: Int?
    /// Persisted for Logbook + single-dive UI. From fixture JSON when present; **`.fit`** import assigns the next chained **#**; backfill fills legacy **`nil`** when **`diveNumberExplicitlyNone`** is **`false`**; when **Settings → Automatically renumber dives** is on (or delete override in tests), **`renumberAllChronologically`** can rewrite **#** after add/delete.
    var diveNumber: Int?
    /// When **`true`**, **`diveNumber`** is intentionally **`nil`** (UI **`-`**); the dive is skipped when computing the next import **#** (chain continues from the last numbered dive earlier in time).
    var diveNumberExplicitlyNone: Bool = false

    // Environmental Conditions
    var waterTempAvgCelsius: Double?
    var waterTempMaxCelsius: Double?
    /// Minimum water temperature (°C). **UDDF:** **`informationafterdive/lowesttemperature`** (K→°C) combined with waypoint min; **FIT:** session min merged with record min (**`DiveImportWaterTemperatureSummary`**).
    var waterTempMinCelsius: Double?

    // Performance Metrics
    var avgAscentRateMetersPerSecond: Double?

    // Location
    var siteName: String?
    var locationName: String?
    /// Import / manual entry GPS latitude (degrees). Paired with **`entryLongitude`**.
    /// Flattened from Codable **`DiveCoordinate`** — CloudKit rejects `NSCodableAttributeType`.
    var entryLatitude: Double?
    /// Import / manual entry GPS longitude (degrees). Paired with **`entryLatitude`**.
    var entryLongitude: Double?

    /// GPS from import / manual entry (entry point). Map uses **`siteCoordinate`** when **`diveSite`** is linked.
    /// Transient wrapper over **`entryLatitude`** / **`entryLongitude`** (CloudKit-safe primitives).
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

    /// Denormalized for **`#Predicate`**; kept in sync with linked catalog or user site id.
    var diveSiteID: UUID?

    // User-Provided Data
    var notes: String?

    // Manual log (overview sheet, large detent — not from import)
    /// **`DiveCurrentStrength`** raw value; **`nil`** = unset.
    var diveCurrentStrengthRaw: String?
    @Transient
    var diveCurrentStrength: DiveCurrentStrength? {
        get { diveCurrentStrengthRaw.flatMap(DiveCurrentStrength.init(rawValue:)) }
        set { diveCurrentStrengthRaw = newValue?.rawValue }
    }
    var surfaceCondition: String?
    var entryType: String?
    /// **`DiveVisibilityRating`** raw value; **`nil`** = unset.
    var diveVisibilityRaw: String?
    @Transient
    var diveVisibility: DiveVisibilityRating? {
        get { diveVisibilityRaw.flatMap(DiveVisibilityRating.init(rawValue:)) }
        set { diveVisibilityRaw = newValue?.rawValue }
    }
    var diveOperatorName: String?
    var diveMasterName: String?
    /// **`PKDrawing`** archive from **`DiveSignaturePadView`**; **`nil`** when empty.
    var diveSignatureData: Data?

    /// **`DiveWaterType`** raw value; **`nil`** → salt water on import / display defaults.
    var diveWaterTypeRaw: String?
    @Transient
    var diveWaterType: DiveWaterType? {
        get { diveWaterTypeRaw.flatMap(DiveWaterType.init(rawValue:)) }
        set { diveWaterTypeRaw = newValue?.rawValue }
    }
    /// Diver ballast weight in **kilograms** (canonical storage).
    var diverWeightKilograms: Double?

    // Tank / cylinder (import: **UDDF** when present; **FIT** has no standard tank SPG fields in decoded messages → **`nil`**)
    /// Material label when known (e.g. **steel**, **aluminum**). **`nil`** if not in file.
    var tankMaterial: String?
    /// Persisted rated size label at import (**`DefaultTankSpecification.storedDescription`**). **`nil`** on legacy rows until metrics run.
    var tankVolumeDescription: String?
    /// Cylinder pressure at start of dive (**psi**). **`nil`** if not in file.
    var tankPressureStartPSI: Double?
    /// Cylinder pressure at end of dive (**psi**). **`nil`** if not in file.
    var tankPressureEndPSI: Double?

    /// Breathing gas category: **Air** (~21% O₂) or **Nitrox** (any other **`oxygenMix`**). **`nil`** when import has no mix.
    var gasType: String?
    /// Fraction of oxygen in the breathing mix, as **percent** (e.g. **21**, **32**). **`nil`** when not in file.
    var oxygenMix: Double?

    /// Surface air consumption (pressure SAC): **psi/min** at the surface. Computed on import when tank pressures, time, and depth allow (**`DiveSACRMVCalculation`**).
    var avgSAC: Double?
    /// Respiratory minute volume at the surface: **L/min**. Computed on import from SAC × tank factor or FIT **`volume_used`** / time.
    var avgRMV: Double?

    /// CloudKit requires optional to-many relationships; **`buddies`** is the app-facing accessor.
    @Relationship(deleteRule: .cascade)
    var buddiesStorage: [DiveBuddyTag]? = []
    @Transient
    var buddies: [DiveBuddyTag] {
        get { buddiesStorage ?? [] }
        set { buddiesStorage = newValue }
    }

    /// Reusable custom labels (**`ActivityTag`**) applied to this dive (unlinked on dive delete; tag rows persist).
    @Relationship(deleteRule: .nullify)
    var activityTagsStorage: [ActivityTag]? = []
    @Transient
    var activityTags: [ActivityTag] {
        get { activityTagsStorage ?? [] }
        set { activityTagsStorage = newValue }
    }

    /// Post-dive photos and videos (**`DiveMediaPhoto`**). Empty until the user adds media.
    @Relationship(deleteRule: .cascade)
    var mediaPhotosStorage: [DiveMediaPhoto]? = []
    @Transient
    var mediaPhotos: [DiveMediaPhoto] {
        get { mediaPhotosStorage ?? [] }
        set { mediaPhotosStorage = newValue }
    }

    /// User-chosen **featured** media (logbook row preview). **`nil`** = default to the oldest gallery item
    /// (**`DiveActivityMediaPresentation.featuredPhotoID`** resolves / falls back when this id is missing).
    var featuredMediaPhotoID: UUID?

    /// Field-guide sightings logged on this dive (**`SightingInstance`**).
    @Relationship(deleteRule: .cascade)
    var marineLifeSightingsStorage: [SightingInstance]? = []
    @Transient
    var marineLifeSightings: [SightingInstance] {
        get { marineLifeSightingsStorage ?? [] }
        set { marineLifeSightingsStorage = newValue }
    }

    /// Buddies tagged on individual media items for this dive (**`DiveMediaBuddyTag`**).
    @Relationship(deleteRule: .cascade)
    var mediaBuddyTagsStorage: [DiveMediaBuddyTag]? = []
    @Transient
    var mediaBuddyTags: [DiveMediaBuddyTag] {
        get { mediaBuddyTagsStorage ?? [] }
        set { mediaBuddyTagsStorage = newValue }
    }

    /// Trips this dive is linked to (at most one **`DiveTripActivityLink`**).
    @Relationship
    var tripActivityLinksStorage: [DiveTripActivityLink]? = []
    @Transient
    var tripActivityLinks: [DiveTripActivityLink] {
        get { tripActivityLinksStorage ?? [] }
        set { tripActivityLinksStorage = newValue }
    }

    /// Gear used on this dive (**`DiveEquipmentEntry`** rows). Created on first link / auto-add.
    @Relationship(deleteRule: .cascade)
    var equipmentList: DiveActivityEquipmentList?

    /// Staged / cached depth-profile samples. Persisted in **`GoDiveUserLocal`** via
    /// **`DiveProfilePointStore`** (not a CloudKit-mirrored relationship).
    @Transient
    var profilePoints: [DiveProfilePoint] = []

    /// Compressed binary depth track for CloudKit sync (**`DiveProfileTrackCodec`**).
    /// Local chart rows live in **`GoDiveUserLocal`**; this blob mirrors across devices.
    var profileTrackData: Data?

    /// Frozen WeatherKit snapshot captured at import (**`ActivityWeatherPersistedSnapshot`** JSON envelope).
    var activityWeatherSnapshotData: Data?

    /// Denormalized for **`#Predicate`** / logbook filtering; kept in sync with **`owner`**.
    var ownerProfileID: UUID?
    @Relationship
    var owner: UserProfile?

    // Metadata
    var rawImportVersion: String?
    /// UDDF **`datetime`** from import file until **`UddfImportedDiveNormalization`** finishes (not persisted).
    @Transient var uddfImportDatetimeRaw: String?
    /// MacDive watch-source rule for naive **`datetime`** (Garmin UTC vs Suunto dive-local); cleared after normalization.
    @Transient var uddfWatchNaiveDatetimeSemantics: UddfMacDiveWatchDatetimeSemantics?

    init(
        id: UUID = UUID(),
        source: DiveSource,
        sourceDiveId: String? = nil,
        startTime: Date,
        timeZoneOffsetSeconds: Int? = nil,
        durationMinutes: Int,
        maxDepthMeters: Double,
        averageDepthMeters: Double? = nil,
        bottomTimeSeconds: Int? = nil,
        surfaceIntervalSeconds: Int? = nil,
        diveNumber: Int? = nil,
        diveNumberExplicitlyNone: Bool = false,
        waterTempAvgCelsius: Double? = nil,
        waterTempMaxCelsius: Double? = nil,
        waterTempMinCelsius: Double? = nil,
        avgAscentRateMetersPerSecond: Double? = nil,
        siteName: String? = nil,
        locationName: String? = nil,
        entryCoordinate: DiveCoordinate? = nil,
        diveSiteID: UUID? = nil,
        notes: String? = nil,
        diveCurrentStrength: DiveCurrentStrength? = nil,
        surfaceCondition: String? = nil,
        entryType: String? = nil,
        diveVisibility: DiveVisibilityRating? = nil,
        diveOperatorName: String? = nil,
        diveMasterName: String? = nil,
        diveSignatureData: Data? = nil,
        diveWaterType: DiveWaterType? = nil,
        diverWeightKilograms: Double? = nil,
        tankMaterial: String? = nil,
        tankVolumeDescription: String? = nil,
        tankPressureStartPSI: Double? = nil,
        tankPressureEndPSI: Double? = nil,
        gasType: String? = nil,
        oxygenMix: Double? = nil,
        avgSAC: Double? = nil,
        avgRMV: Double? = nil,
        rawImportVersion: String? = nil
    ) {
        self.id = id
        self.source = source
        self.sourceDiveId = sourceDiveId
        self.startTime = startTime
        self.timeZoneOffsetSeconds = timeZoneOffsetSeconds
        self.durationMinutes = durationMinutes
        self.maxDepthMeters = maxDepthMeters
        self.averageDepthMeters = averageDepthMeters
        self.bottomTimeSeconds = bottomTimeSeconds
        self.surfaceIntervalSeconds = surfaceIntervalSeconds
        self.diveNumber = diveNumber
        self.diveNumberExplicitlyNone = diveNumberExplicitlyNone
        self.waterTempAvgCelsius = waterTempAvgCelsius
        self.waterTempMaxCelsius = waterTempMaxCelsius
        self.waterTempMinCelsius = waterTempMinCelsius
        self.avgAscentRateMetersPerSecond = avgAscentRateMetersPerSecond
        self.siteName = siteName
        self.locationName = locationName
        self.entryCoordinate = entryCoordinate
        self.diveSiteID = diveSiteID
        self.notes = notes
        self.diveCurrentStrength = diveCurrentStrength
        self.surfaceCondition = surfaceCondition
        self.entryType = entryType
        self.diveVisibility = diveVisibility
        self.diveOperatorName = diveOperatorName
        self.diveMasterName = diveMasterName
        self.diveSignatureData = diveSignatureData
        self.diveWaterType = diveWaterType
        self.diverWeightKilograms = diverWeightKilograms
        self.tankMaterial = tankMaterial
        self.tankVolumeDescription = tankVolumeDescription
        self.tankPressureStartPSI = tankPressureStartPSI
        self.tankPressureEndPSI = tankPressureEndPSI
        self.gasType = gasType
        self.oxygenMix = oxygenMix
        self.avgSAC = avgSAC
        self.avgRMV = avgRMV
        self.rawImportVersion = rawImportVersion
    }
}

extension DiveActivity {
    /// Resolves the linked catalog/user site from **`diveSiteID`** when a model context is attached.
    var resolvedLinkedSite: DiveLinkedSiteResolver.ResolvedSite? {
        guard let diveSiteID, let modelContext else { return nil }
        return try? DiveLinkedSiteResolver.resolve(id: diveSiteID, modelContext: modelContext)
    }

    /// Catalog **`DiveSite`** coordinates when linked and usable.
    var siteCoordinate: DiveCoordinate? {
        guard let site = resolvedLinkedSite else { return nil }
        return DiveMapCoordinateResolver.coordinate(from: site)
    }

    /// Coordinate for map pin: linked site (context or **`catalogSites`** by id), then entry GPS, then name lookup.
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

    /// Primary site title: linked catalog name, else import **`siteName`**.
    var resolvedSiteName: String? {
        if let site = resolvedLinkedSite, let linked = DiveSiteCatalogMatcher.resolvedCatalogSiteName(for: site) {
            return linked
        }
        let imported = siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return imported.isEmpty ? nil : imported
    }

    /// UI / display default when **`diveCurrentStrength`** is **`nil`** (legacy rows after schema add).
    var resolvedDiveCurrentStrength: DiveCurrentStrength {
        get { diveCurrentStrength ?? .none }
        set { diveCurrentStrength = newValue == .none ? nil : newValue }
    }

    /// UI default when **`diveWaterType`** is **`nil`** (legacy rows and import default).
    var resolvedDiveWaterType: DiveWaterType {
        get { diveWaterType ?? .saltwater }
        set { diveWaterType = newValue }
    }

    /// **`EquipmentItem.id`** values on this dive's equipment list.
    var equipmentItemIDs: [UUID] {
        guard let entries = equipmentList?.entries else { return [] }
        return entries.map(\.equipmentItemID)
    }

    /// **`mediaPhotos`** ordered for gallery UI (**`capturedAt`** oldest first, then **`sortOrder`**, then **`id`**).
    var sortedMediaPhotos: [DiveMediaPhoto] {
        mediaPhotos.sorted {
            GalleryMediaOrdering.isOrderedBefore(
                GalleryMediaOrderFields(id: $0.id, capturedAt: $0.capturedAt, sortOrder: $0.sortOrder),
                GalleryMediaOrderFields(id: $1.id, capturedAt: $1.capturedAt, sortOrder: $1.sortOrder)
            )
        }
    }

    /// Logbook row: **`#n`** or **`-`** when hidden or unset.
    var diveNumberLogbookLabel: String {
        if diveNumberExplicitlyNone { return "-" }
        if let n = diveNumber {
            return "#\(n)"
        }
        return "-"
    }

    /// Overview / plain fields: decimal text or **`-`** when hidden or unset.
    var diveNumberPlainLabel: String {
        if diveNumberExplicitlyNone { return "-" }
        return diveNumber.map(String.init) ?? "-"
    }
}

// MARK: - Details tab: Gas section

extension DiveActivity {
    /// Tank hero label (**`gasType`** + **`oxygenMix`** %), or **No gas specified**.
    var tankHeroGasMixLabel: String {
        DiveGasMixImport.tankHeroLabel(gasType: gasType, oxygenMix: oxygenMix)
    }

    /// **Gas** row (**`gasType`**), or **—** when unknown.
    var gasDetailsGasTypeLine: String {
        Self.gasDetailsTrimmedTextOrDash(gasType)
    }

    /// **O₂ mix** row from **`oxygenMix`** percent, or **—** when unknown.
    var gasDetailsOxygenMixLine: String {
        guard let oxygenMix else { return "—" }
        return "\(Int(oxygenMix.rounded()))%"
    }

    /// **Tank type** row — import material when set, otherwise **Settings** default material.
    func gasDetailsTankTypeLine(
        defaultSpecification: DefaultTankSpecification = DiveActivityTankDefaults.resolvedSpecification()
    ) -> String {
        if let trimmed = tankMaterial?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            return trimmed
        }
        return defaultSpecification.materialLabel
    }

    /// **Volume** row — **Settings → Default tank** (**`DiveQuantityFormatting`**).
    func gasDetailsTankVolumeLine(
        displayUnits: DiveDisplayUnitSystem,
        defaultSpecification: DefaultTankSpecification = DiveActivityTankDefaults.resolvedSpecification()
    ) -> String {
        DiveQuantityFormatting.tankVolumeDisplay(system: displayUnits, specification: defaultSpecification)
    }

    /// Beginning cylinder pressure from stored **psi** for the given display system.
    func gasDetailsBeginningPressureLine(displayUnits: DiveDisplayUnitSystem) -> String {
        DiveQuantityFormatting.cylinderPressure(fromPSI: tankPressureStartPSI, system: displayUnits)
    }

    /// Ending cylinder pressure from stored **psi** for the given display system.
    func gasDetailsEndingPressureLine(displayUnits: DiveDisplayUnitSystem) -> String {
        DiveQuantityFormatting.cylinderPressure(fromPSI: tankPressureEndPSI, system: displayUnits)
    }

    /// Minimized tank hero / consumption section SAC row — computed from cylinder pressures, not stored **`avgSAC`**.
    func tankHeroSACRateLine(displayUnits: DiveDisplayUnitSystem) -> String? {
        guard tankPressureStartPSI != nil, tankPressureEndPSI != nil else { return nil }
        guard let sac = DiveSACRMVCalculation.sacPSIPerMinute(from: sacRMVCalculationInput()) else { return nil }
        return DiveQuantityFormatting.surfaceAirConsumption(sacPSIPerMinute: sac, system: displayUnits)
    }

    /// Minimized tank hero / consumption section RMV row — computed from pressures + default tank, not stored **`avgRMV`**.
    func tankHeroRMVRateLine(displayUnits: DiveDisplayUnitSystem) -> String? {
        guard tankPressureStartPSI != nil, tankPressureEndPSI != nil else { return nil }
        let input = sacRMVCalculationInput()
        guard let sac = DiveSACRMVCalculation.sacPSIPerMinute(from: input),
              let rmv = DiveSACRMVCalculation.rmvLitersPerMinute(from: input, sacPSIPerMinute: sac)
        else { return nil }
        return DiveQuantityFormatting.respiratoryMinuteVolume(litersPerMinute: rmv, system: displayUnits)
    }

    private func sacRMVCalculationInput(volumeUsedSurfaceLiters: Double? = nil) -> DiveSACRMVCalculation.Input {
        let waterColumn: DiveSACRMVCalculation.WaterColumn = resolvedDiveWaterType == .freshwater ? .freshwater : .saltwater
        var input = DiveSACRMVCalculation.Input(
            tankPressureStartPSI: tankPressureStartPSI,
            tankPressureEndPSI: tankPressureEndPSI,
            bottomTimeSeconds: bottomTimeSeconds,
            durationMinutes: durationMinutes,
            averageDepthMeters: averageDepthMeters,
            maxDepthMeters: maxDepthMeters,
            tankVolumeDescription: tankVolumeDescription,
            volumeUsedSurfaceLiters: volumeUsedSurfaceLiters
        )
        input.waterColumn = waterColumn
        return input
    }

    private static func gasDetailsTrimmedTextOrDash(_ value: String?) -> String {
        guard let raw = value else { return "—" }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
}
