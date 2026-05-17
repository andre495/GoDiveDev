import Foundation

/// Normalizes water temperature between **FIT** session **`Int8` °C** aggregates and **`Double` °C** record samples.
enum DiveImportWaterTemperatureSummary {

    /// **`session*`** are whole °C from **`SessionMesg`**; **`recordTemps`** are °C from **`RecordMesg`** (or UDDF waypoint temps).
    /// Session values win for **avg** when present; **max** / **min** take the extrema across session and records so spikes are not lost.
    static func mergedAvgMaxMinCelsius(
        sessionAvg: Int8?,
        sessionMax: Int8?,
        sessionMin: Int8?,
        recordTemps: [Double]
    ) -> (avg: Double?, max: Double?, min: Double?) {
        let recordAvg: Double? = recordTemps.isEmpty ? nil : (recordTemps.reduce(0, +) / Double(recordTemps.count))
        let recordMax = recordTemps.max()
        let recordMin = recordTemps.min()

        let avg = sessionAvg.map(Double.init) ?? recordAvg

        let sessionMaxD = sessionMax.map(Double.init)
        let sessionMinD = sessionMin.map(Double.init)
        let maxOut = [sessionMaxD, recordMax].compactMap { $0 }.max()
        let minOut = [sessionMinD, recordMin].compactMap { $0 }.min()

        return (avg, maxOut, minOut)
    }
}

/// Safe conversion of FIT **`UInt32`** time fields (e.g. **`ndl_time`**, **`time_to_surface`**) into **`Int`** seconds for **`DiveProfilePoint`**.
enum DiveImportFitUInt32Seconds {
    static func toOptionalInt(_ value: UInt32?) -> Int? {
        guard let value else { return nil }
        return Int(value)
    }
}
