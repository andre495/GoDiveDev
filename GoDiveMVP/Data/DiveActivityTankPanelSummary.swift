import Foundation

/// Read-only **`tankPressurePSI`** rollups on **`DiveProfilePoint`** for the tank tab.
enum DiveActivityTankPanelSummary {
    struct ProfilePressureStats: Equatable {
        /// Number of profile samples with non-**`nil`** cylinder pressure.
        var sampleCount: Int
        var minPSI: Double?
        var maxPSI: Double?
    }

    static func profilePressureStats(from points: [DiveProfilePoint]) -> ProfilePressureStats {
        let values = points.compactMap(\.tankPressurePSI)
        guard !values.isEmpty else {
            return ProfilePressureStats(sampleCount: 0, minPSI: nil, maxPSI: nil)
        }
        return ProfilePressureStats(
            sampleCount: values.count,
            minPSI: values.min(),
            maxPSI: values.max()
        )
    }

    /// **Remaining gas** level **0...1** from dive-level cylinder pressures (**`end / start`**), for tank visuals.
    /// Returns **`nil`** when **`start`** is missing or **≤ 0**, or **`end`** is missing (**no animation / keep “full”**).
    static func remainingPressureFillFraction(startPSI: Double?, endPSI: Double?) -> Double? {
        guard let start = startPSI, start > 0, let end = endPSI else { return nil }
        guard end >= 0 else { return nil }
        return min(1, max(0, end / start))
    }
}
