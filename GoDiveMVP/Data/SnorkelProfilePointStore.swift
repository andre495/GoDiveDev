import Foundation
import SwiftData

/// Local-only **`SnorkelProfilePoint`** rows keyed by **`snorkelActivityID`** (no SwiftData relationship to
/// **`SnorkelActivity`** — points live in **`GoDiveUserLocal`**, outside CloudKit mirroring).
///
/// CloudKit sync uses **`SnorkelActivity.swimTrackData`** (**`SnorkelSwimTrackCodec`**); materialize
/// local rows when a synced snorkel has a track blob but no local samples yet.
enum SnorkelProfilePointStore {

    nonisolated static func fetchPoints(
        for snorkelActivityID: UUID,
        modelContext: ModelContext
    ) throws -> [SnorkelProfilePoint] {
        try modelContext.fetch(
            FetchDescriptor<SnorkelProfilePoint>(
                predicate: #Predicate { $0.snorkelActivityID == snorkelActivityID },
                sortBy: [SortDescriptor(\.timestamp)]
            )
        )
    }

    nonisolated static func insertStagedPoints(
        for activity: SnorkelActivity,
        into modelContext: ModelContext
    ) {
        let activityID = activity.id
        for point in activity.profilePoints {
            point.snorkelActivityID = activityID
            if point.modelContext == nil {
                modelContext.insert(point)
            }
        }
    }

    /// Encodes staged/local points onto **`activity.swimTrackData`** for CloudKit sync.
    nonisolated static func syncTrackData(from activity: SnorkelActivity) {
        let points = activity.profilePoints
        guard !points.isEmpty else {
            activity.swimTrackData = nil
            return
        }
        activity.swimTrackData = try? SnorkelSwimTrackCodec.encode(
            points: points,
            activityStartTime: activity.startTime
        )
    }

    nonisolated static func insertStagedPointsAndSyncTrack(
        for activity: SnorkelActivity,
        into modelContext: ModelContext
    ) {
        insertStagedPoints(for: activity, into: modelContext)
        syncTrackData(from: activity)
    }

    nonisolated static func deletePoints(
        for snorkelActivityID: UUID,
        modelContext: ModelContext
    ) throws {
        try modelContext.delete(
            model: SnorkelProfilePoint.self,
            where: #Predicate { $0.snorkelActivityID == snorkelActivityID }
        )
    }

    nonisolated static func loadPoints(
        into activity: SnorkelActivity,
        modelContext: ModelContext
    ) throws {
        activity.profilePoints = try fetchPoints(for: activity.id, modelContext: modelContext)
    }

    /// When local rows are missing but **`swimTrackData`** is present (CloudKit import), decode and insert.
    @discardableResult
    nonisolated static func materializeFromTrackIfNeeded(
        activity: SnorkelActivity,
        modelContext: ModelContext
    ) throws -> Int {
        let existing = try fetchPoints(for: activity.id, modelContext: modelContext)
        if !existing.isEmpty {
            activity.profilePoints = existing
            return 0
        }
        guard let data = activity.swimTrackData, !data.isEmpty else {
            activity.profilePoints = []
            return 0
        }
        let samples = try SnorkelSwimTrackCodec.decode(data, activityStartTime: activity.startTime)
        let activityID = activity.id
        var inserted: [SnorkelProfilePoint] = []
        inserted.reserveCapacity(samples.count)
        for sample in samples {
            let point = sample.makeProfilePoint(snorkelActivityID: activityID)
            modelContext.insert(point)
            inserted.append(point)
        }
        activity.profilePoints = inserted
        return inserted.count
    }

    nonisolated static func ensurePointsLoaded(
        for activity: SnorkelActivity,
        modelContext: ModelContext
    ) throws {
        if activity.profilePoints.isEmpty {
            _ = try materializeFromTrackIfNeeded(activity: activity, modelContext: modelContext)
        }
        if activity.profilePoints.isEmpty {
            try loadPoints(into: activity, modelContext: modelContext)
        }
    }
}
