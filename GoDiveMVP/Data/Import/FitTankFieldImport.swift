import Foundation
import FITSwiftSDK

/// Maps Garmin **FIT** tank messages (**`TankUpdate`**, **`TankSummary`**) onto **`DiveActivity`** / **`DiveProfilePoint`** tank fields (pressures stored as **psi**).
enum FitTankFieldImport {

    private static let barToPSI = 14.5037738007

    /// Absolute cylinder pressure from **bar** (FIT **`TankUpdate`** / **`TankSummary`**) to **psi**.
    static func psi(fromBar bar: Double?) -> Double? {
        guard let bar, bar > 0 else { return nil }
        return bar * barToPSI
    }

    /// Non-**`nil`** **sensor** ids (**`AntChannelId`**) from tank updates and summaries, unique sorted.
    static func distinctTankSensorIds(tankUpdates: [TankUpdateMesg], tankSummaries: [TankSummaryMesg]) -> [UInt32] {
        var set = Set<UInt32>()
        for u in tankUpdates {
            if let s = u.getSensor() { set.insert(s) }
        }
        for s in tankSummaries {
            if let sensor = s.getSensor() { set.insert(sensor) }
        }
        return set.sorted()
    }

    /// **>2** distinct tank streams usually means merged / multi-diver data (not normal sidemount). **2** streams = sidemount — pick a primary by update count.
    static func validateDistinctTankSensorCount(_ distinctCount: Int) throws {
        guard distinctCount <= 2 else {
            throw FitDecodeError.multipleDistinctTankSensorsAmbiguous(sensorCount: distinctCount)
        }
    }

    /// Sensor id with the most **`TankUpdate`** rows; on a tie prefers the **lower** id. If there are no updates, uses the sole summary’s sensor, or the first summary’s sensor when counts tie.
    static func primaryTankSensorId(tankUpdates: [TankUpdateMesg], tankSummaries: [TankSummaryMesg]) -> UInt32? {
        guard !tankUpdates.isEmpty else {
            let summarySensors = tankSummaries.compactMap { $0.getSensor() }
            if summarySensors.count == 1 { return summarySensors[0] }
            // No per-sample updates: sidemount may still have two summaries — pick lowest **sensor** id deterministically.
            if summarySensors.count >= 2 { return summarySensors.min() }
            return nil
        }

        var counts = [UInt32: Int]()
        for u in tankUpdates {
            guard let s = u.getSensor() else { continue }
            counts[s, default: 0] += 1
        }
        guard !counts.isEmpty else { return nil }

        return counts.keys.max { a, b in
            let ca = counts[a, default: 0]
            let cb = counts[b, default: 0]
            if ca != cb { return ca < cb }
            return a < b
        }
    }

    /// Chronological **(time, bar)** for **`sensor`**, sorted ascending.
    static func sortedTankPressureSamples(tankUpdates: [TankUpdateMesg], sensor: UInt32) -> [(Date, Double)] {
        tankUpdates.compactMap { u -> (Date, Double)? in
            guard u.getSensor() == sensor,
                  let t = u.getTimestamp()?.date,
                  let bar = u.getPressure(), bar > 0
            else { return nil }
            return (t, bar)
        }
        .sorted { $0.0 < $1.0 }
    }

    /// **`TankSummary`** for the given **sensor**, if any.
    static func tankSummary(forSensor sensor: UInt32, in summaries: [TankSummaryMesg]) -> TankSummaryMesg? {
        summaries.first { $0.getSensor() == sensor }
    }

    /// Start / end **psi** from summary, or from first / last **tank update** for **sensor** when summary is missing.
    static func diveLevelTankPressuresPSI(
        sensor: UInt32,
        tankSummaries: [TankSummaryMesg],
        tankUpdates: [TankUpdateMesg]
    ) -> (start: Double?, end: Double?) {
        if let sum = tankSummary(forSensor: sensor, in: tankSummaries) {
            let start = psi(fromBar: sum.getStartPressure())
            let end = psi(fromBar: sum.getEndPressure())
            if start != nil || end != nil {
                return (start, end)
            }
        }
        let samples = sortedTankPressureSamples(tankUpdates: tankUpdates, sensor: sensor)
        guard let firstBar = samples.first?.1, let lastBar = samples.last?.1 else {
            return (nil, nil)
        }
        return (psi(fromBar: firstBar), psi(fromBar: lastBar))
    }

    /// Human-readable gas **used** from **`TankSummary.volume_used`** (**liters** in FIT profile) plus **~ft³** (surface equivalent).
    static func volumeUsedDescription(volumeUsedLiters: Double?) -> String? {
        guard let liters = volumeUsedLiters, liters > 0 else { return nil }
        let cubicFeet = liters / 28.316846592
        return String(format: "%.0f L used (~%.1f ft³) (FIT)", liters, cubicFeet)
    }

    /// Nearest tank sample in **bar** → **psi**; **`nil`** if no sample within **`maxTimeDelta`** of **`recordTime`**.
    static func nearestTankPressurePSI(
        recordTime: Date,
        sortedSamples: [(Date, Double)],
        maxTimeDelta: TimeInterval = 5.0
    ) -> Double? {
        guard !sortedSamples.isEmpty else { return nil }

        var bestDelta = TimeInterval.greatestFiniteMagnitude
        var bestBar: Double?

        func consider(_ index: Int) {
            guard sortedSamples.indices.contains(index) else { return }
            let (t, bar) = sortedSamples[index]
            let d = abs(t.timeIntervalSince(recordTime))
            if d < bestDelta {
                bestDelta = d
                bestBar = bar
            }
        }

        var low = 0
        var high = sortedSamples.count - 1
        while low < high {
            let mid = (low + high) / 2
            if sortedSamples[mid].0 < recordTime {
                low = mid + 1
            } else {
                high = mid
            }
        }

        let idx = min(low, max(0, sortedSamples.count - 1))
        consider(idx)
        consider(idx - 1)

        guard bestDelta <= maxTimeDelta, let bar = bestBar else { return nil }
        return psi(fromBar: bar)
    }
}
