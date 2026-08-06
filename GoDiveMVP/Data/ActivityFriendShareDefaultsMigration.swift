import Foundation
import SwiftData

/// Idempotent backfill: snapshot current global buddy-share defaults onto activities that predate
/// creation-time capture so changing Settings later does not retroactively alter them.
enum ActivityFriendShareDefaultsMigration: Sendable {

    static func captureMissingDefaults(modelContext: ModelContext) throws {
        let needingDives = try modelContext.fetchCount(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate {
                    $0.friendShareBuddySettingsConfigured == false
                        && $0.friendShareBuddyDefaultsCaptured == false
                }
            )
        )
        let needingSnorkels = try modelContext.fetchCount(
            FetchDescriptor<SnorkelActivity>(
                predicate: #Predicate {
                    $0.friendShareBuddySettingsConfigured == false
                        && $0.friendShareBuddyDefaultsCaptured == false
                }
            )
        )
        guard needingDives > 0 || needingSnorkels > 0 else { return }

        var changed = false

        let dives = try modelContext.fetch(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate {
                    $0.friendShareBuddySettingsConfigured == false
                        && $0.friendShareBuddyDefaultsCaptured == false
                }
            )
        )
        for dive in dives {
            ActivityFriendShareConfiguration.captureGlobalBuddyShareDefaultsIfNeeded(on: dive)
            changed = true
        }

        let snorkels = try modelContext.fetch(
            FetchDescriptor<SnorkelActivity>(
                predicate: #Predicate {
                    $0.friendShareBuddySettingsConfigured == false
                        && $0.friendShareBuddyDefaultsCaptured == false
                }
            )
        )
        for snorkel in snorkels {
            ActivityFriendShareConfiguration.captureGlobalBuddyShareDefaultsIfNeeded(on: snorkel)
            changed = true
        }

        if changed {
            try modelContext.save()
        }
    }
}
