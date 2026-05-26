import CoreGraphics
import Foundation

/// Depth and elapsed time on the dive profile when media was captured.
struct DiveMediaCaptureContext: Equatable, Sendable {
    var elapsedSeconds: Double
    var depthMeters: Double
}

/// A dive photo/video positioned on the depth profile time axis.
struct DiveDepthProfileMediaMarker: Identifiable, Equatable, Sendable {
    var mediaID: UUID
    var elapsedSeconds: Double
    var depthMeters: Double
    var isVideo: Bool

    var id: UUID { mediaID }
}

/// Maps **`DiveMediaPhoto.capturedAt`** onto the depth chart elapsed-time axis.
enum DiveDepthProfileMediaPlotting {

    nonisolated static let markerThumbnailSize: CGFloat = 28
    nonisolated static let markerThumbnailCornerRadius: CGFloat = 5

    struct DiveTimeAxis: Equatable, Sendable {
        var referenceTime: Date
        var durationSeconds: Double
    }

    /// Same time base as **`DiveDepthProfileSeries.samples(fromProfilePoints:)`** when profile data exists.
    nonisolated static func diveTimeAxis(
        activityStartTime: Date,
        durationMinutes: Int,
        profilePoints: [DiveProfilePoint]
    ) -> DiveTimeAxis {
        let sorted = profilePoints.sorted { $0.timestamp < $1.timestamp }
        if let first = sorted.first, let last = sorted.last {
            let span = last.timestamp.timeIntervalSince(first.timestamp)
            return DiveTimeAxis(
                referenceTime: first.timestamp,
                durationSeconds: max(span, 0.001)
            )
        }
        return DiveTimeAxis(
            referenceTime: activityStartTime,
            durationSeconds: max(Double(durationMinutes) * 60, 0.001)
        )
    }

    nonisolated static func markers(
        mediaPhotos: [DiveMediaPhoto],
        profileSamples: [DiveDepthProfileSample],
        activityStartTime: Date,
        durationMinutes: Int,
        profilePoints: [DiveProfilePoint]
    ) -> [DiveDepthProfileMediaMarker] {
        guard profileSamples.count >= 2 else { return [] }

        let sortedMedia = mediaPhotos.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        var markers: [DiveDepthProfileMediaMarker] = []
        for photo in sortedMedia {
            guard let context = captureContext(
                for: photo,
                profileSamples: profileSamples,
                activityStartTime: activityStartTime,
                durationMinutes: durationMinutes,
                profilePoints: profilePoints
            ) else { continue }

            markers.append(
                DiveDepthProfileMediaMarker(
                    mediaID: photo.id,
                    elapsedSeconds: context.elapsedSeconds,
                    depthMeters: context.depthMeters,
                    isVideo: (DiveMediaKind(rawValue: photo.mediaKind) ?? .image) == .video
                )
            )
        }
        return markers.sorted { $0.elapsedSeconds < $1.elapsedSeconds }
    }

    nonisolated static func captureContextsByMediaID(
        mediaPhotos: [DiveMediaPhoto],
        profileSamples: [DiveDepthProfileSample],
        activityStartTime: Date,
        durationMinutes: Int,
        profilePoints: [DiveProfilePoint]
    ) -> [UUID: DiveMediaCaptureContext] {
        var contexts: [UUID: DiveMediaCaptureContext] = [:]
        for photo in mediaPhotos {
            if let context = captureContext(
                for: photo,
                profileSamples: profileSamples,
                activityStartTime: activityStartTime,
                durationMinutes: durationMinutes,
                profilePoints: profilePoints
            ) {
                contexts[photo.id] = context
            }
        }
        return contexts
    }

    /// **`nil`** when **`capturedAt`** is missing or falls outside the profile time window.
    nonisolated static func captureContext(
        for media: DiveMediaPhoto,
        profileSamples: [DiveDepthProfileSample],
        activityStartTime: Date,
        durationMinutes: Int,
        profilePoints: [DiveProfilePoint]
    ) -> DiveMediaCaptureContext? {
        guard let capturedAt = media.capturedAt else { return nil }
        guard profileSamples.count >= 2 else { return nil }

        let axis = diveTimeAxis(
            activityStartTime: activityStartTime,
            durationMinutes: durationMinutes,
            profilePoints: profilePoints
        )
        let elapsed = capturedAt.timeIntervalSince(axis.referenceTime)
        guard elapsed >= 0, elapsed <= axis.durationSeconds else { return nil }

        return DiveMediaCaptureContext(
            elapsedSeconds: elapsed,
            depthMeters: depthMeters(atElapsed: elapsed, in: profileSamples)
        )
    }

    /// Linear depth along the profile polyline at **`elapsedSeconds`**.
    nonisolated static func depthMeters(atElapsed elapsedSeconds: Double, in samples: [DiveDepthProfileSample]) -> Double {
        guard let first = samples.first else { return 0 }
        guard samples.count > 1 else { return first.depthMeters }

        if elapsedSeconds <= first.elapsedSeconds {
            return first.depthMeters
        }
        if let last = samples.last, elapsedSeconds >= last.elapsedSeconds {
            return last.depthMeters
        }

        for index in 0 ..< samples.count - 1 {
            let left = samples[index]
            let right = samples[index + 1]
            guard elapsedSeconds >= left.elapsedSeconds, elapsedSeconds <= right.elapsedSeconds else { continue }
            let span = right.elapsedSeconds - left.elapsedSeconds
            guard span > 0 else { return right.depthMeters }
            let fraction = (elapsedSeconds - left.elapsedSeconds) / span
            return left.depthMeters + (right.depthMeters - left.depthMeters) * fraction
        }
        return first.depthMeters
    }
}
