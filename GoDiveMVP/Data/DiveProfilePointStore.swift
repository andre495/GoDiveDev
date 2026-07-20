import Foundation
import SwiftData

/// Local-only **`DiveProfilePoint`** rows keyed by **`diveActivityID`** (no SwiftData relationship to
/// **`DiveActivity`** — points live in **`GoDiveUserLocal`**, outside CloudKit mirroring).
///
/// CloudKit sync uses **`DiveActivity.profileTrackData`** (**`DiveProfileTrackCodec`**); materialize
/// local rows when a synced dive has a track blob but no local samples yet.
enum DiveProfilePointStore {

    nonisolated static func fetchPoints(
        for diveActivityID: UUID,
        modelContext: ModelContext
    ) throws -> [DiveProfilePoint] {
        try modelContext.fetch(
            FetchDescriptor<DiveProfilePoint>(
                predicate: #Predicate { $0.diveActivityID == diveActivityID },
                sortBy: [SortDescriptor(\.timestamp)]
            )
        )
    }

    /// Inserts staged **`activity.profilePoints`** after the dive row is inserted.
    nonisolated static func insertStagedPoints(
        for activity: DiveActivity,
        into modelContext: ModelContext
    ) {
        let diveID = activity.id
        for point in activity.profilePoints {
            point.diveActivityID = diveID
            if point.modelContext == nil {
                modelContext.insert(point)
            }
        }
    }

    /// Encodes staged/local points onto **`activity.profileTrackData`** for CloudKit sync.
    nonisolated static func syncTrackData(from activity: DiveActivity) {
        let points = activity.profilePoints
        guard !points.isEmpty else {
            activity.profileTrackData = nil
            return
        }
        activity.profileTrackData = try? DiveProfileTrackCodec.encode(
            points: points,
            diveStartTime: activity.startTime
        )
    }

    /// Inserts staged points and refreshes the synced track blob.
    nonisolated static func insertStagedPointsAndSyncTrack(
        for activity: DiveActivity,
        into modelContext: ModelContext
    ) {
        insertStagedPoints(for: activity, into: modelContext)
        syncTrackData(from: activity)
    }

    nonisolated static func deletePoints(
        for diveActivityID: UUID,
        modelContext: ModelContext
    ) throws {
        try modelContext.delete(
            model: DiveProfilePoint.self,
            where: #Predicate { $0.diveActivityID == diveActivityID }
        )
    }

    /// Loads persisted samples into the dive’s transient **`profilePoints`** cache.
    nonisolated static func loadPoints(
        into activity: DiveActivity,
        modelContext: ModelContext
    ) throws {
        activity.profilePoints = try fetchPoints(for: activity.id, modelContext: modelContext)
    }

    /// When local rows are missing but **`profileTrackData`** is present (CloudKit import), decode and insert.
    /// Idempotent: no-op when local points already exist.
    @discardableResult
    nonisolated static func materializeFromTrackIfNeeded(
        activity: DiveActivity,
        modelContext: ModelContext
    ) throws -> Int {
        let existing = try fetchPoints(for: activity.id, modelContext: modelContext)
        if !existing.isEmpty {
            activity.profilePoints = existing
            return 0
        }
        guard let data = activity.profileTrackData, !data.isEmpty else {
            activity.profilePoints = []
            return 0
        }
        let samples = try DiveProfileTrackCodec.decode(data, diveStartTime: activity.startTime)
        let diveID = activity.id
        var inserted: [DiveProfilePoint] = []
        inserted.reserveCapacity(samples.count)
        for sample in samples {
            let point = sample.makeProfilePoint(diveActivityID: diveID)
            modelContext.insert(point)
            inserted.append(point)
        }
        activity.profilePoints = inserted
        return inserted.count
    }

    /// Ensures local points are available for charts (fetch or materialize from track blob).
    nonisolated static func ensurePointsLoaded(
        for activity: DiveActivity,
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
