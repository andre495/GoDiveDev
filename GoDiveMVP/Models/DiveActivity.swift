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
    var id: UUID
    /// Import / entry origin (Garmin, MacDive, manual). Persisted column was **`deviceSource`**.
    @Attribute(originalName: "deviceSource")
    var source: DiveSource
    var sourceDiveId: String?

    // Core Dive Data
    /// Dive start instant (UTC). Display via **`formattedStartDateTime()`** using **`timeZoneOffsetSeconds`** when set.
    var startTime: Date
    /// Seconds east of UTC for dive-local display (from UDDF **`timezone`**, **`Z`**, or **`±HH:MM`** on import).
    var timeZoneOffsetSeconds: Int?
    var durationMinutes: Int
    var maxDepthMeters: Double
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
    /// GPS from import / manual entry (entry point). Map uses **`siteCoordinate`** when **`diveSite`** is linked.
    @Attribute(originalName: "coordinate")
    var entryCoordinate: DiveCoordinate?

    /// Denormalized for **`#Predicate`**; kept in sync with **`diveSite`**.
    var diveSiteID: UUID?
    @Relationship(deleteRule: .nullify)
    var diveSite: DiveSite?

    // User-Provided Data
    var notes: String?

    // Manual log (overview sheet, large detent — not from import)
    /// **`nil`** = none / unset (optional for SwiftData migration — do not use a non-optional enum default).
    var diveCurrentStrength: DiveCurrentStrength?
    var surfaceCondition: String?
    var entryType: String?
    var diveVisibility: DiveVisibilityRating?
    var diveOperatorName: String?
    var diveMasterName: String?
    /// **`PKDrawing`** archive from **`DiveSignaturePadView`**; **`nil`** when empty.
    var diveSignatureData: Data?

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

    @Relationship(deleteRule: .cascade)
    var buddies: [DiveBuddyTag] = []

    /// Reusable custom labels (**`ActivityTag`**) applied to this dive (unlinked on dive delete; tag rows persist).
    @Relationship(deleteRule: .nullify)
    var activityTags: [ActivityTag] = []

    /// Post-dive photos and videos (**`DiveMediaPhoto`**). Empty until the user adds media.
    @Relationship(deleteRule: .cascade)
    var mediaPhotos: [DiveMediaPhoto] = []

    /// User-chosen **featured** media (logbook row preview). **`nil`** = default to the oldest gallery item
    /// (**`DiveActivityMediaPresentation.featuredPhotoID`** resolves / falls back when this id is missing).
    var featuredMediaPhotoID: UUID?

    /// Field-guide sightings logged on this dive (**`SightingInstance`**).
    @Relationship(deleteRule: .cascade)
    var marineLifeSightings: [SightingInstance] = []

    /// Trips this dive is linked to (usually one **`DiveTripActivityLink`**).
    @Relationship
    var tripActivityLinks: [DiveTripActivityLink] = []

    /// Gear used on this dive (**`DiveEquipmentEntry`** rows). Created on first link / auto-add.
    @Relationship(deleteRule: .cascade)
    var equipmentList: DiveActivityEquipmentList?

    // Time-series profile (Garmin record messages mapped to canonical points)
    @Relationship(deleteRule: .cascade)
    var profilePoints: [DiveProfilePoint] = []

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
        diveSite: DiveSite? = nil,
        notes: String? = nil,
        diveCurrentStrength: DiveCurrentStrength? = nil,
        surfaceCondition: String? = nil,
        entryType: String? = nil,
        diveVisibility: DiveVisibilityRating? = nil,
        diveOperatorName: String? = nil,
        diveMasterName: String? = nil,
        diveSignatureData: Data? = nil,
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
        self.diveSite = diveSite
        self.notes = notes
        self.diveCurrentStrength = diveCurrentStrength
        self.surfaceCondition = surfaceCondition
        self.entryType = entryType
        self.diveVisibility = diveVisibility
        self.diveOperatorName = diveOperatorName
        self.diveMasterName = diveMasterName
        self.diveSignatureData = diveSignatureData
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
    /// Catalog **`DiveSite`** coordinates when linked and usable.
    var siteCoordinate: DiveCoordinate? {
        guard let site = diveSite else { return nil }
        return DiveMapCoordinateResolver.coordinate(from: site)
    }

    /// Coordinate for map pin: linked site first, then entry GPS, then unlinked name lookup in **`catalogSites`**.
    func resolvedMapCoordinate(catalogSites: [DiveSite]) -> DiveCoordinate? {
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
        let linked = diveSite?.siteName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !linked.isEmpty { return linked }
        let imported = siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return imported.isEmpty ? nil : imported
    }

    /// UI / display default when **`diveCurrentStrength`** is **`nil`** (legacy rows after schema add).
    var resolvedDiveCurrentStrength: DiveCurrentStrength {
        get { diveCurrentStrength ?? .none }
        set { diveCurrentStrength = newValue == .none ? nil : newValue }
    }

    /// **`EquipmentItem.id`** values on this dive's equipment list.
    var equipmentItemIDs: [UUID] {
        guard let entries = equipmentList?.entries else { return [] }
        return entries.map(\.equipmentItemID)
    }

    /// **`mediaPhotos`** ordered for gallery UI (**`capturedAt`** oldest first, then **`sortOrder`**, then **`id`**).
    var sortedMediaPhotos: [DiveMediaPhoto] {
        DiveActivityMediaPresentation.sortedPhotos(on: self)
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

    /// Minimized tank hero / SAC row from **`avgSAC`** (**psi/min** or **bar/min**).
    func tankHeroSACRateLine(displayUnits: DiveDisplayUnitSystem) -> String? {
        DiveQuantityFormatting.surfaceAirConsumption(sacPSIPerMinute: avgSAC, system: displayUnits)
    }

    /// Minimized tank hero / RMV row from **`avgRMV`** (**L/min** or **cu ft/min**).
    func tankHeroRMVRateLine(displayUnits: DiveDisplayUnitSystem) -> String? {
        DiveQuantityFormatting.respiratoryMinuteVolume(litersPerMinute: avgRMV, system: displayUnits)
    }

    private static func gasDetailsTrimmedTextOrDash(_ value: String?) -> String {
        guard let raw = value else { return "—" }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
}
