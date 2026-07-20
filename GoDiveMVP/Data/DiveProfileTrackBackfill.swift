import Foundation
import SwiftData
import os

/// One-shot: encode **`DiveActivity.profileTrackData`** from local **`DiveProfilePoint`** rows when missing.
///
/// Enables CloudKit sync of depth tracks for dives imported before the track-blob path shipped.
enum DiveProfileTrackBackfill: Sendable {

    nonisolated static let completedDefaultsKey = "godive.profileTrackBackfill.v1.completed"

    private nonisolated static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PrimoSoftware.GoDiveMVP",
        category: "ProfileTrackBackfill"
    )

    /// Encodes missing track blobs. Skips when the defaults fingerprint says work already finished.
    nonisolated static func backfillIfNeeded(
        modelContext: ModelContext,
        defaults: UserDefaults = .standard
    ) throws {
        if defaults.bool(forKey: completedDefaultsKey) {
            return
        }

        let activities = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        var encoded = 0
        for activity in activities {
            if let existing = activity.profileTrackData, !existing.isEmpty {
                continue
            }
            let points = try DiveProfilePointStore.fetchPoints(
                for: activity.id,
                modelContext: modelContext
            )
            guard !points.isEmpty else { continue }
            activity.profilePoints = points
            DiveProfilePointStore.syncTrackData(from: activity)
            if activity.profileTrackData != nil {
                encoded += 1
            }
        }
        if modelContext.hasChanges {
            try modelContext.save()
        }
        defaults.set(true, forKey: completedDefaultsKey)
        if encoded > 0 {
            log.info("Encoded profileTrackData for \(encoded, privacy: .public) dives")
        }
    }

    /// Test hook — clears the completed flag.
    nonisolated static func resetCompletedFlag(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: completedDefaultsKey)
    }
}
