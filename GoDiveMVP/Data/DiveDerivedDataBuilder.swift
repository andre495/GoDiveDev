import Foundation

/// Value snapshots for building dive derived chart/media data off the main actor.
struct DiveDerivedProfilePointSnapshot: Sendable, Equatable {
    var timestamp: Date
    var depthMeters: Double
    var tankPressurePSI: Double?
}

struct DiveDerivedMediaSnapshot: Sendable, Equatable {
    var id: UUID
    var sortOrder: Int
    var mediaKind: String
    var capturedAt: Date?
}

/// Precomputed chart + media plotting payloads for **`ViewSingleActivity`**.
struct DiveDerivedDataBuildResult: Sendable {
    var depthSamples: [DiveDepthProfileSample] = []
    var pressureSamples: [DiveDepthProfilePressureSample] = []
    var mediaMarkers: [DiveDepthProfileMediaMarker] = []
    var mediaCaptureContextsByID: [UUID: DiveMediaCaptureContext] = [:]
    var profileGasStats = DiveActivityTankPanelSummary.ProfilePressureStats(
        sampleCount: 0,
        minPSI: nil,
        maxPSI: nil
    )
}

struct DiveDerivedDataBuildInput: Sendable {
    var profilePointSnapshots: [DiveDerivedProfilePointSnapshot]
    var sortedMediaSnapshots: [DiveDerivedMediaSnapshot]
    var activityStartTime: Date
    var durationMinutes: Int
}

/// Builds heavy dive derived data off the main thread from plain snapshots.
enum DiveDerivedDataBuilder: Sendable {

    nonisolated static func build(from input: DiveDerivedDataBuildInput) -> DiveDerivedDataBuildResult {
        let sortedProfiles = input.profilePointSnapshots.sorted { $0.timestamp < $1.timestamp }
        let depthTuples = sortedProfiles.map { (timestamp: $0.timestamp, depthMeters: $0.depthMeters) }
        let depthSamples = DiveDepthProfileSeries.samples(sortedAscending: depthTuples)
        let pressureSamples = pressureSamples(fromSortedProfiles: sortedProfiles)
        let pressureValues = sortedProfiles.compactMap(\.tankPressurePSI)
        let profileGasStats = profilePressureStats(from: pressureValues)

        let axis = diveTimeAxis(
            sortedProfiles: sortedProfiles,
            activityStartTime: input.activityStartTime,
            durationMinutes: input.durationMinutes
        )

        let mediaMarkers = markers(
            mediaItems: input.sortedMediaSnapshots,
            profileSamples: depthSamples,
            axis: axis
        )
        let mediaCaptureContextsByID = captureContextsByMediaID(
            mediaItems: input.sortedMediaSnapshots,
            profileSamples: depthSamples,
            axis: axis
        )

        return DiveDerivedDataBuildResult(
            depthSamples: depthSamples,
            pressureSamples: pressureSamples,
            mediaMarkers: mediaMarkers,
            mediaCaptureContextsByID: mediaCaptureContextsByID,
            profileGasStats: profileGasStats
        )
    }

    nonisolated static func sortedMediaSnapshots(from snapshots: [DiveDerivedMediaSnapshot]) -> [DiveDerivedMediaSnapshot] {
        snapshots.sorted { lhs, rhs in
            mediaOrderedBefore(lhs, rhs)
        }
    }

    private nonisolated static func pressureSamples(
        fromSortedProfiles profiles: [DiveDerivedProfilePointSnapshot]
    ) -> [DiveDepthProfilePressureSample] {
        guard let first = profiles.first else { return [] }
        let t0 = first.timestamp
        return profiles.compactMap { point in
            guard let psi = point.tankPressurePSI else { return nil }
            return DiveDepthProfilePressureSample(
                elapsedSeconds: point.timestamp.timeIntervalSince(t0),
                pressurePSI: psi
            )
        }
    }

    private nonisolated static func profilePressureStats(
        from values: [Double]
    ) -> DiveActivityTankPanelSummary.ProfilePressureStats {
        guard !values.isEmpty else {
            return DiveActivityTankPanelSummary.ProfilePressureStats(
                sampleCount: 0,
                minPSI: nil,
                maxPSI: nil
            )
        }
        return DiveActivityTankPanelSummary.ProfilePressureStats(
            sampleCount: values.count,
            minPSI: values.min(),
            maxPSI: values.max()
        )
    }

    private nonisolated static func diveTimeAxis(
        sortedProfiles: [DiveDerivedProfilePointSnapshot],
        activityStartTime: Date,
        durationMinutes: Int
    ) -> DiveDepthProfileMediaPlotting.DiveTimeAxis {
        if let first = sortedProfiles.first, let last = sortedProfiles.last {
            let span = last.timestamp.timeIntervalSince(first.timestamp)
            return DiveDepthProfileMediaPlotting.DiveTimeAxis(
                referenceTime: first.timestamp,
                durationSeconds: max(span, 0.001)
            )
        }
        return DiveDepthProfileMediaPlotting.DiveTimeAxis(
            referenceTime: activityStartTime,
            durationSeconds: max(Double(durationMinutes) * 60, 0.001)
        )
    }

    private nonisolated static func markers(
        mediaItems: [DiveDerivedMediaSnapshot],
        profileSamples: [DiveDepthProfileSample],
        axis: DiveDepthProfileMediaPlotting.DiveTimeAxis
    ) -> [DiveDepthProfileMediaMarker] {
        guard profileSamples.count >= 2 else { return [] }

        var markers: [DiveDepthProfileMediaMarker] = []
        for item in mediaItems {
            guard let context = captureContext(for: item, profileSamples: profileSamples, axis: axis) else {
                continue
            }
            markers.append(
                DiveDepthProfileMediaMarker(
                    mediaID: item.id,
                    elapsedSeconds: context.elapsedSeconds,
                    depthMeters: context.depthMeters,
                    isVideo: (DiveMediaKind(rawValue: item.mediaKind) ?? .image) == .video
                )
            )
        }
        return markers.sorted { $0.elapsedSeconds < $1.elapsedSeconds }
    }

    private nonisolated static func captureContextsByMediaID(
        mediaItems: [DiveDerivedMediaSnapshot],
        profileSamples: [DiveDepthProfileSample],
        axis: DiveDepthProfileMediaPlotting.DiveTimeAxis
    ) -> [UUID: DiveMediaCaptureContext] {
        var contexts: [UUID: DiveMediaCaptureContext] = [:]
        for item in mediaItems {
            if let context = captureContext(for: item, profileSamples: profileSamples, axis: axis) {
                contexts[item.id] = context
            }
        }
        return contexts
    }

    private nonisolated static func captureContext(
        for media: DiveDerivedMediaSnapshot,
        profileSamples: [DiveDepthProfileSample],
        axis: DiveDepthProfileMediaPlotting.DiveTimeAxis
    ) -> DiveMediaCaptureContext? {
        guard let capturedAt = media.capturedAt else { return nil }
        guard profileSamples.count >= 2 else { return nil }
        let elapsed = capturedAt.timeIntervalSince(axis.referenceTime)
        guard elapsed >= 0, elapsed <= axis.durationSeconds else { return nil }

        return DiveMediaCaptureContext(
            elapsedSeconds: elapsed,
            depthMeters: DiveDepthProfileMediaPlotting.depthMeters(atElapsed: elapsed, in: profileSamples)
        )
    }

    fileprivate nonisolated static func mediaOrderedBefore(
        _ lhs: DiveDerivedMediaSnapshot,
        _ rhs: DiveDerivedMediaSnapshot
    ) -> Bool {
        switch (lhs.capturedAt, rhs.capturedAt) {
        case let (left?, right?):
            if left != right { return left < right }
        case (nil, .some):
            return false
        case (.some, nil):
            return true
        case (nil, nil):
            break
        }
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

#if canImport(SwiftData)
import SwiftData

extension DiveDerivedDataBuilder {
    nonisolated static func profilePointSnapshots(from points: [DiveProfilePoint]) -> [DiveDerivedProfilePointSnapshot] {
        points.map {
            DiveDerivedProfilePointSnapshot(
                timestamp: $0.timestamp,
                depthMeters: $0.depthMeters,
                tankPressurePSI: $0.tankPressurePSI
            )
        }
    }

    nonisolated static func mediaSnapshots(from photos: [DiveMediaPhoto]) -> [DiveDerivedMediaSnapshot] {
        photos.map {
            DiveDerivedMediaSnapshot(
                id: $0.id,
                sortOrder: $0.sortOrder,
                mediaKind: $0.mediaKind,
                capturedAt: $0.capturedAt
            )
        }
    }

    nonisolated static func sortedMediaSnapshots(from photos: [DiveMediaPhoto]) -> [DiveDerivedMediaSnapshot] {
        sortedMediaSnapshots(from: mediaSnapshots(from: photos))
    }
}
#endif
