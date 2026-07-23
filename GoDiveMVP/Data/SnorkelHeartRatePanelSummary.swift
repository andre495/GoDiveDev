import Foundation

/// Heart-rate rollups from profile samples for the snorkel **heart rate** tab.
enum SnorkelHeartRatePanelSummary {
    struct ProfileHeartRateStats: Equatable, Sendable {
        var sampleCount: Int
        var minBPM: Int?
        var maxBPM: Int?
    }

    nonisolated static func profileHeartRateStats(from bpmValues: [Int]) -> ProfileHeartRateStats {
        guard !bpmValues.isEmpty else {
            return ProfileHeartRateStats(sampleCount: 0, minBPM: nil, maxBPM: nil)
        }
        return ProfileHeartRateStats(
            sampleCount: bpmValues.count,
            minBPM: bpmValues.min(),
            maxBPM: bpmValues.max()
        )
    }

    nonisolated static func formattedBPM(_ value: Int?) -> String {
        guard let value, value > 0 else { return "—" }
        return "\(value)"
    }
}
