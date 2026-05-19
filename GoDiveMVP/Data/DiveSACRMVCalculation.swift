import Foundation

/// Surface air consumption (**SAC**, pressure at surface) and respiratory minute volume (**RMV**)
/// per [Scuba Scribbles — How to Calculate SAC Rate](https://www.scubascribbles.com/how-to-calculate-sac-rate/)
/// (single-cylinder; double-tank section ignored).
enum DiveSACRMVCalculation: Sendable {

    /// Salt: **33 ft** per **1 ATA**; fresh: **34 ft** per **1 ATA** (article).
    enum WaterColumn: Sendable {
        case saltwater
        case freshwater
    }

    struct Input: Sendable {
        var tankPressureStartPSI: Double?
        var tankPressureEndPSI: Double?
        /// Prefer **`bottomTimeSeconds / 60`** when set on import.
        var bottomTimeSeconds: Int?
        var durationMinutes: Int
        var averageDepthMeters: Double?
        var maxDepthMeters: Double
        var waterColumn: WaterColumn = .saltwater
        /// Import text (e.g. UDDF **`80 L (0.080 m³)`**). Ignored when it describes gas **used** (FIT).
        var tankVolumeDescription: String?
        /// Working pressure for tank factor when not inferable from start pressure. **AL80** default **3000 psi**.
        var defaultRatedPressurePSI: Double = 3000
        /// FIT **`TankSummary.volume_used`** (surface-equivalent **L**); enables RMV without rated tank size.
        var volumeUsedSurfaceLiters: Double?
    }

    struct Result: Sendable, Equatable {
        /// Pressure SAC at surface (**psi/min**).
        let sacPSIPerMinute: Double
        /// RMV at surface (**L/min**).
        let rmvLitersPerMinute: Double
    }

    enum MissingRequirement: String, Sendable, CaseIterable, Equatable {
        case tankStartAndEndPressure = "Tank starting and ending pressure"
        case pressureConsumed = "Positive pressure drop (start − end)"
        case diveDuration = "Bottom time or dive duration"
        case averageDepth = "Average depth (or max depth fallback)"
        case rmvTankVolumeOrVolumeUsed = "Tank rated volume (or FIT volume-used) for RMV"
    }

    static func compute(_ input: Input) -> Result? {
        guard let sac = sacPSIPerMinute(from: input) else { return nil }
        guard let rmv = rmvLitersPerMinute(from: input, sacPSIPerMinute: sac) else { return nil }
        return Result(sacPSIPerMinute: sac, rmvLitersPerMinute: rmv)
    }

    /// Requirements still needed for a full **SAC + RMV** result (for logging / diagnostics).
    static func missingRequirements(for input: Input) -> [MissingRequirement] {
        var missing: [MissingRequirement] = []
        if sacPSIPerMinute(from: input) == nil {
            if input.tankPressureStartPSI == nil || input.tankPressureEndPSI == nil {
                missing.append(.tankStartAndEndPressure)
            } else if pressureConsumedPSI(from: input) == nil {
                missing.append(.pressureConsumed)
            }
            if consumptionDurationMinutes(from: input) == nil {
                missing.append(.diveDuration)
            }
            if resolvedAverageDepthMeters(from: input) == nil {
                missing.append(.averageDepth)
            }
        }
        if let sac = sacPSIPerMinute(from: input), rmvLitersPerMinute(from: input, sacPSIPerMinute: sac) == nil {
            missing.append(.rmvTankVolumeOrVolumeUsed)
        }
        return missing
    }

    // MARK: - SAC (pressure at surface)

    static func sacPSIPerMinute(from input: Input) -> Double? {
        guard let psiConsumed = pressureConsumedPSI(from: input),
              let minutes = consumptionDurationMinutes(from: input),
              minutes > 0,
              let depthM = resolvedAverageDepthMeters(from: input),
              depthM >= 0
        else { return nil }

        let ata = atmospheresAbsolute(depthMeters: depthM, waterColumn: input.waterColumn)
        guard ata > 0 else { return nil }

        let depthConsumptionPSIPerMinute = psiConsumed / minutes
        return depthConsumptionPSIPerMinute / ata
    }

    // MARK: - RMV (L/min at surface)

    static func rmvLitersPerMinute(from input: Input, sacPSIPerMinute: Double) -> Double? {
        if let ratedLiters = ratedTankVolumeLiters(from: input.tankVolumeDescription),
           let ratedPSI = resolvedRatedPressurePSI(from: input),
           ratedLiters > 0,
           ratedPSI > 0
        {
            let litersPerPSI = ratedLiters / ratedPSI
            return sacPSIPerMinute * litersPerPSI
        }

        if let used = input.volumeUsedSurfaceLiters,
           used > 0,
           let minutes = consumptionDurationMinutes(from: input),
           minutes > 0
        {
            return used / minutes
        }

        return nil
    }

    // MARK: - Helpers

    static func atmospheresAbsolute(depthMeters: Double, waterColumn: WaterColumn) -> Double {
        let metersPerAtmosphere: Double
        switch waterColumn {
        case .saltwater:
            metersPerAtmosphere = 33.0 / 3.280839895013123
        case .freshwater:
            metersPerAtmosphere = 34.0 / 3.280839895013123
        }
        return 1.0 + depthMeters / metersPerAtmosphere
    }

    static func pressureConsumedPSI(from input: Input) -> Double? {
        guard let start = input.tankPressureStartPSI,
              let end = input.tankPressureEndPSI,
              start > 0
        else { return nil }
        let consumed = start - end
        guard consumed > 0 else { return nil }
        return consumed
    }

    static func consumptionDurationMinutes(from input: Input) -> Double? {
        if let bottom = input.bottomTimeSeconds, bottom > 0 {
            return Double(bottom) / 60.0
        }
        if input.durationMinutes > 0 {
            return Double(input.durationMinutes)
        }
        return nil
    }

    static func resolvedAverageDepthMeters(from input: Input) -> Double? {
        if let avg = input.averageDepthMeters, avg > 0 { return avg }
        if input.maxDepthMeters > 0 { return input.maxDepthMeters }
        return nil
    }

    /// Rated cylinder size for RMV — **Settings → Default tank** (import text ignored).
    static func ratedTankVolumeLiters(
        from tankVolumeDescription: String?,
        userDefaults: UserDefaults = .standard
    ) -> Double? {
        _ = tankVolumeDescription
        return DiveActivityTankDefaults.resolvedSpecification(userDefaults: userDefaults).ratedVolumeSurfaceLiters
    }

    static func resolvedRatedPressurePSI(from input: Input) -> Double? {
        if let start = input.tankPressureStartPSI, start >= 2500 {
            return start
        }
        return input.defaultRatedPressurePSI
    }
}

// MARK: - DiveActivity

extension DiveActivity {

    /// Fills **`avgSAC`** / **`avgRMV`** after import (or seed) when inputs allow.
    func applyImportedGasConsumptionMetrics(volumeUsedSurfaceLiters: Double?) {
        let specification = DiveActivityTankDefaults.resolvedSpecification()
        tankVolumeDescription = specification.storedDescription
        if tankMaterial?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            tankMaterial = specification.materialLabel
        }
        let input = DiveSACRMVCalculation.Input(
            tankPressureStartPSI: tankPressureStartPSI,
            tankPressureEndPSI: tankPressureEndPSI,
            bottomTimeSeconds: bottomTimeSeconds,
            durationMinutes: durationMinutes,
            averageDepthMeters: averageDepthMeters,
            maxDepthMeters: maxDepthMeters,
            tankVolumeDescription: tankVolumeDescription,
            volumeUsedSurfaceLiters: volumeUsedSurfaceLiters
        )
        if let result = DiveSACRMVCalculation.compute(input) {
            avgSAC = result.sacPSIPerMinute
            avgRMV = result.rmvLitersPerMinute
        } else {
            avgSAC = DiveSACRMVCalculation.sacPSIPerMinute(from: input)
            avgRMV = nil
        }
    }
}
