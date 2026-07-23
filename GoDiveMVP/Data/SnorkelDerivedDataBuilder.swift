import Foundation

struct SnorkelDerivedProfilePointSnapshot: Sendable, Equatable {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var heartRateBPM: Int?
}

struct SnorkelDerivedDataBuildResult: Sendable {
    var sortedProfilePoints: [SnorkelDerivedProfilePointSnapshot] = []
    var heartRateSamples: [SnorkelHeartRateProfileSample] = []
    var trackCoordinates: [DiveCoordinate] = []
    var heartRateStats = SnorkelHeartRatePanelSummary.ProfileHeartRateStats(
        sampleCount: 0,
        minBPM: nil,
        maxBPM: nil
    )
}

enum SnorkelDerivedDataBuilder: Sendable {

    nonisolated static func build(
        from profileSnapshots: [SnorkelDerivedProfilePointSnapshot]
    ) -> SnorkelDerivedDataBuildResult {
        let sorted = profileSnapshots.sorted { $0.timestamp < $1.timestamp }
        let heartRateSamples = heartRateSamples(fromSorted: sorted)
        let trackCoordinates = trackCoordinates(fromSorted: sorted)
        let bpmValues = sorted.compactMap(\.heartRateBPM)
        let heartRateStats = SnorkelHeartRatePanelSummary.profileHeartRateStats(from: bpmValues)

        return SnorkelDerivedDataBuildResult(
            sortedProfilePoints: sorted,
            heartRateSamples: heartRateSamples,
            trackCoordinates: trackCoordinates,
            heartRateStats: heartRateStats
        )
    }

    nonisolated private static func heartRateSamples(
        fromSorted sorted: [SnorkelDerivedProfilePointSnapshot]
    ) -> [SnorkelHeartRateProfileSample] {
        guard let first = sorted.first else { return [] }
        let t0 = first.timestamp
        return sorted.compactMap { point in
            guard let bpm = point.heartRateBPM, bpm > 0 else { return nil }
            return SnorkelHeartRateProfileSample(
                elapsedSeconds: point.timestamp.timeIntervalSince(t0),
                heartRateBPM: bpm
            )
        }
    }

    nonisolated private static func trackCoordinates(
        fromSorted sorted: [SnorkelDerivedProfilePointSnapshot]
    ) -> [DiveCoordinate] {
        sorted.compactMap { point in
            let coordinate = DiveCoordinate(latitude: point.latitude, longitude: point.longitude)
            return DiveMapCoordinateResolver.isUsable(coordinate) ? coordinate : nil
        }
    }
}
