import Foundation
import SwiftData

// MARK: - DiveProfilePoint

/// Time-series sample for dive profile visualization and future insights (ascent rate, stops, etc.).
/// **Canonical:** **`depthMeters`**, **`temperatureCelsius`**, **`ascentRateMetersPerSecond`**, **`tankPressurePSI`** (see **`DiveActivity`**).
@Model
final class DiveProfilePoint {

    var timestamp: Date = Date()
    var depthMeters: Double = 0
    var temperatureCelsius: Double?
    var ascentRateMetersPerSecond: Double?
    var ndlSeconds: Int?
    var timeToSurfaceSeconds: Int?
    /// Cylinder pressure at this sample (**psi**). **UDDF:** waypoint **`tankpressure`** (Pa→psi). **FIT:** **`TankUpdateMesg`** aligned to **`RecordMesg`** time (**`FitTankFieldImport.nearestTankPressurePSI`**).
    var tankPressurePSI: Double?

    /// **FIT `RecordMesg`:** heart rate (**bpm**). **UDDF:** typically **`nil`**.
    var heartRateBPM: Int?
    /// **FIT `RecordMesg`:** inspired **O₂** partial pressure (**bar**, native FIT field scale).
    var po2Bars: Double?
    /// **FIT `RecordMesg`:** tissue **N₂** load (native **`UInt16`** stored as **`Int`**).
    var n2Load: Int?
    /// **FIT `RecordMesg`:** **CNS** load (native **`UInt8`** stored as **`Int`**, commonly **0…100**).
    var cnsLoad: Int?

    /// Denormalized for batch **`delete(model:where:)`** (avoids per-row cascade deletes).
    var diveActivityID: UUID?

    @Relationship(inverse: \DiveActivity.profilePointsStorage)
    var dive: DiveActivity?

    init(
        timestamp: Date,
        depthMeters: Double,
        temperatureCelsius: Double? = nil,
        ascentRateMetersPerSecond: Double? = nil,
        ndlSeconds: Int? = nil,
        timeToSurfaceSeconds: Int? = nil,
        tankPressurePSI: Double? = nil,
        heartRateBPM: Int? = nil,
        po2Bars: Double? = nil,
        n2Load: Int? = nil,
        cnsLoad: Int? = nil,
        dive: DiveActivity? = nil
    ) {
        self.timestamp = timestamp
        self.depthMeters = depthMeters
        self.temperatureCelsius = temperatureCelsius
        self.ascentRateMetersPerSecond = ascentRateMetersPerSecond
        self.ndlSeconds = ndlSeconds
        self.timeToSurfaceSeconds = timeToSurfaceSeconds
        self.tankPressurePSI = tankPressurePSI
        self.heartRateBPM = heartRateBPM
        self.po2Bars = po2Bars
        self.n2Load = n2Load
        self.cnsLoad = cnsLoad
        self.diveActivityID = dive?.id
        self.dive = dive
    }

    /// Links this sample to a dive and updates **`diveActivityID`** for batch deletes.
    func link(to dive: DiveActivity) {
        DiveActivityChildRecordLinking.link(self, to: dive)
    }
}
