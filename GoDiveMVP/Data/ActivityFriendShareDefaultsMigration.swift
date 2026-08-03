import Foundation
import SwiftData

/// One-time backfill: snapshot current global buddy-share defaults onto activities that predate
/// creation-time capture so changing Settings later does not retroactively alter them.
enum ActivityFriendShareDefaultsMigration: Sendable {

    static func captureMissingDefaults(modelContext: ModelContext) throws {
        var changed = false

        let dives = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        for dive in dives where !dive.friendShareBuddySettingsConfigured && !dive.friendShareBuddyDefaultsCaptured {
            ActivityFriendShareConfiguration.captureGlobalBuddyShareDefaultsIfNeeded(on: dive)
            changed = true
        }

        let snorkels = try modelContext.fetch(FetchDescriptor<SnorkelActivity>())
        for snorkel in snorkels where !snorkel.friendShareBuddySettingsConfigured && !snorkel.friendShareBuddyDefaultsCaptured {
            ActivityFriendShareConfiguration.captureGlobalBuddyShareDefaultsIfNeeded(on: snorkel)
            changed = true
        }

        if changed {
            try modelContext.save()
        }
    }
}
