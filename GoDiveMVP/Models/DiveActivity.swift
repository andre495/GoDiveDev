import Foundation
import SwiftData

// MARK: - DiveActivity

/// **Canonical storage (import / SwiftData):** depth fields in **meters**, water temps in **°C**, ascent in **m/s**,
/// cylinder pressures in **psi** (FIT bar and UDDF Pa are converted on import). **`tankVolumeDescription`** is
/// importer text (typically **L** / **m³**). **Settings → Imperial units** only changes **on-screen** formatting
/// via **`DiveQuantityFormatting`** + **`EnvironmentValues.diveDisplayUnitSystem`** — values here are not rewritten.
@Model
final class DiveActivity {

    // Core Identity
    var id: UUID
    var deviceSource: DeviceSource
    var sourceDiveId: String?

    // Core Dive Data
    var startTime: Date
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
    var coordinate: DiveCoordinate?

    // User-Provided Data
    var notes: String?

    // Tank / cylinder (import: **UDDF** when present; **FIT** has no standard tank SPG fields in decoded messages → **`nil`**)
    /// Material label when known (e.g. **steel**, **aluminum**). **`nil`** if not in file.
    var tankMaterial: String?
    /// Human-readable size from import (e.g. volume in **L** derived from **`tankvolume`** m³). **`nil`** if not in file.
    var tankVolumeDescription: String?
    /// Cylinder pressure at start of dive (**psi**). **`nil`** if not in file.
    var tankPressureStartPSI: Double?
    /// Cylinder pressure at end of dive (**psi**). **`nil`** if not in file.
    var tankPressureEndPSI: Double?

    /// Breathing gas category: **Air** (~21% O₂) or **Nitrox** (any other **`oxygenMix`**). **`nil`** when import has no mix.
    var gasType: String?
    /// Fraction of oxygen in the breathing mix, as **percent** (e.g. **21**, **32**). **`nil`** when not in file.
    var oxygenMix: Double?

    @Relationship(deleteRule: .cascade)
    var buddies: [DiveBuddyTag] = []

    // Time-series profile (Garmin record messages mapped to canonical points)
    @Relationship(deleteRule: .cascade)
    var profilePoints: [DiveProfilePoint] = []

    /// Denormalized for **`#Predicate`** / logbook filtering; kept in sync with **`owner`**.
    var ownerProfileID: UUID?
    @Relationship
    var owner: UserProfile?

    // Metadata
    var rawImportVersion: String?

    init(
        id: UUID = UUID(),
        deviceSource: DeviceSource,
        sourceDiveId: String? = nil,
        startTime: Date,
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
        coordinate: DiveCoordinate? = nil,
        notes: String? = nil,
        tankMaterial: String? = nil,
        tankVolumeDescription: String? = nil,
        tankPressureStartPSI: Double? = nil,
        tankPressureEndPSI: Double? = nil,
        gasType: String? = nil,
        oxygenMix: Double? = nil,
        rawImportVersion: String? = nil
    ) {
        self.id = id
        self.deviceSource = deviceSource
        self.sourceDiveId = sourceDiveId
        self.startTime = startTime
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
        self.coordinate = coordinate
        self.notes = notes
        self.tankMaterial = tankMaterial
        self.tankVolumeDescription = tankVolumeDescription
        self.tankPressureStartPSI = tankPressureStartPSI
        self.tankPressureEndPSI = tankPressureEndPSI
        self.gasType = gasType
        self.oxygenMix = oxygenMix
        self.rawImportVersion = rawImportVersion
    }
}

extension DiveActivity {
    /// Logbook row: **`#n`** or **`-`** when there is no number.
    var diveNumberLogbookLabel: String {
        if let n = diveNumber {
            return "#\(n)"
        }
        return "-"
    }

    /// Overview / plain fields: decimal text or **`-`**.
    var diveNumberPlainLabel: String {
        diveNumber.map(String.init) ?? "-"
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

    /// **Tank type** row (**`tankMaterial`**), trimmed, or **—** when unknown / blank.
    var gasDetailsTankTypeLine: String {
        Self.gasDetailsTrimmedTextOrDash(tankMaterial)
    }

    /// **Volume** row from **`tankVolumeDescription`** for the given display system (**`DiveQuantityFormatting`**).
    func gasDetailsTankVolumeLine(displayUnits: DiveDisplayUnitSystem) -> String {
        DiveQuantityFormatting.tankVolumeDisplay(storedDescription: tankVolumeDescription, system: displayUnits)
    }

    /// Beginning cylinder pressure from stored **psi** for the given display system.
    func gasDetailsBeginningPressureLine(displayUnits: DiveDisplayUnitSystem) -> String {
        DiveQuantityFormatting.cylinderPressure(fromPSI: tankPressureStartPSI, system: displayUnits)
    }

    /// Ending cylinder pressure from stored **psi** for the given display system.
    func gasDetailsEndingPressureLine(displayUnits: DiveDisplayUnitSystem) -> String {
        DiveQuantityFormatting.cylinderPressure(fromPSI: tankPressureEndPSI, system: displayUnits)
    }

    private static func gasDetailsTrimmedTextOrDash(_ value: String?) -> String {
        guard let raw = value else { return "—" }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
}
