import Foundation
import SwiftData
import os

/// One-shot: encode **`SnorkelActivity.swimTrackData`** from local **`SnorkelProfilePoint`** rows when missing.
///
/// Also nudges CloudKit export for snorkel sessions imported while private mirroring was off.
enum SnorkelSwimTrackBackfill: Sendable {

    nonisolated static let completedDefaultsKey = "godive.snorkelSwimTrackBackfill.v1.completed"

    private nonisolated static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PrimoSoftware.GoDiveMVP",
        category: "SnorkelSwimTrackBackfill"
    )

    nonisolated static func backfillIfNeeded(
        modelContext: ModelContext,
        defaults: UserDefaults = .standard
    ) throws {
        if defaults.bool(forKey: completedDefaultsKey) {
            return
        }

        let activities = try modelContext.fetch(FetchDescriptor<SnorkelActivity>())
        var encoded = 0
        for activity in activities {
            if let existing = activity.swimTrackData, !existing.isEmpty {
                continue
            }
            let points = try SnorkelProfilePointStore.fetchPoints(
                for: activity.id,
                modelContext: modelContext
            )
            guard !points.isEmpty else { continue }
            activity.profilePoints = points
            SnorkelProfilePointStore.syncTrackData(from: activity)
            if activity.swimTrackData != nil {
                encoded += 1
            }
        }
        if modelContext.hasChanges {
            try modelContext.save()
        }
        defaults.set(true, forKey: completedDefaultsKey)
        if encoded > 0 {
            log.info("Encoded swimTrackData for \(encoded, privacy: .public) snorkel sessions")
        }
    }

    nonisolated static func resetCompletedFlag(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: completedDefaultsKey)
    }
}
