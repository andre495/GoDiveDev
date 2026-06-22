import Foundation

/// One ranked buddy on the Home leaderboard (dives shared with the signed-in diver).
struct HomeBuddyLeaderboardEntry: Sendable, Equatable, Identifiable {
    let id: UUID
    let displayName: String
    let profilePhoto: Data?
    let diveCount: Int
    let rank: Int
}

/// Aggregates buddy tags across owned dives for the Home **Top buddies** tile.
enum HomeBuddyLeaderboardPresentation {

    nonisolated static let displayLimit = 3

    struct TagInput: Sendable, Equatable {
        let buddyID: UUID
        let displayName: String
        let profilePhoto: Data?
        let diveActivityID: UUID
    }

    nonisolated static func shouldShow(diveCount: Int, entries: [HomeBuddyLeaderboardEntry]) -> Bool {
        diveCount > 0 && !entries.isEmpty
    }

    nonisolated static func topEntries(
        from tags: [TagInput],
        limit: Int = displayLimit,
        excludingBuddyID: UUID? = nil
    ) -> [HomeBuddyLeaderboardEntry] {
        guard !tags.isEmpty else { return [] }

        struct Accumulator {
            var displayName: String
            var profilePhoto: Data?
            var diveIDs: Set<UUID> = []
        }

        var byBuddyID: [UUID: Accumulator] = [:]
        for tag in tags {
            guard tag.buddyID != excludingBuddyID else { continue }
            var bucket = byBuddyID[tag.buddyID] ?? Accumulator(
                displayName: tag.displayName,
                profilePhoto: tag.profilePhoto
            )
            bucket.displayName = tag.displayName
            if tag.profilePhoto != nil {
                bucket.profilePhoto = tag.profilePhoto
            }
            bucket.diveIDs.insert(tag.diveActivityID)
            byBuddyID[tag.buddyID] = bucket
        }

        let ranked = byBuddyID.map { buddyID, bucket in
            (buddyID: buddyID, bucket: bucket, count: bucket.diveIDs.count)
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.bucket.displayName.localizedCaseInsensitiveCompare(rhs.bucket.displayName) == .orderedAscending
        }

        return ranked.prefix(limit).enumerated().map { index, row in
            HomeBuddyLeaderboardEntry(
                id: row.buddyID,
                displayName: row.bucket.displayName,
                profilePhoto: row.bucket.profilePhoto,
                diveCount: row.count,
                rank: index + 1
            )
        }
    }

    nonisolated static func diveCountLabel(count: Int) -> String {
        count == 1 ? "1 dive" : "\(count) dives"
    }
}

/// Main-actor capture of buddy tags from **`DiveActivity`** rows.
enum HomeBuddyLeaderboardSeeding {
    @MainActor
    static func tagInputs(from activities: [DiveActivity]) -> [HomeBuddyLeaderboardPresentation.TagInput] {
        activities.flatMap { activity in
            activity.buddies.compactMap { tag -> HomeBuddyLeaderboardPresentation.TagInput? in
                let buddyID = tag.buddyID ?? tag.buddy?.id
                guard let buddyID else { return nil }
                return HomeBuddyLeaderboardPresentation.TagInput(
                    buddyID: buddyID,
                    displayName: tag.displayName,
                    profilePhoto: tag.buddy?.profilePhoto,
                    diveActivityID: activity.id
                )
            }
        }
    }
}
