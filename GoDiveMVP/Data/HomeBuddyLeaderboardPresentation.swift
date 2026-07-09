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

    /// Home always reserves the **Top buddies** band so empty and populated roots share the same seam.
    nonisolated static func shouldShow(diveCount: Int, entries: [HomeBuddyLeaderboardEntry]) -> Bool {
        _ = diveCount
        _ = entries
        return true
    }

    nonisolated static let emptyFootnote = "Tag buddies on your dives"
    nonisolated static let emptySlotLabel = "—"
    nonisolated static let emptyAccessibilityLabel = "Top buddies, no buddies tagged yet"

    /// Placeholder ranks **1…displayLimit** when the owner has no tagged buddies yet.
    nonisolated static func displayEntries(
        from entries: [HomeBuddyLeaderboardEntry]
    ) -> [HomeBuddyLeaderboardEntry] {
        guard !entries.isEmpty else { return [] }
        return Array(entries.prefix(displayLimit))
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
                tagInput(from: tag, diveActivityID: activity.id)
            }
        }
    }

    /// Tag inputs from denormalized **`DiveBuddyTag`** rows — does not require **`DiveActivity.buddies`** to be faulted in (pushed buddy/trip pages).
    @MainActor
    static func tagInputs(
        from diveBuddyTags: [DiveBuddyTag],
        ownerDiveIDs: Set<UUID>
    ) -> [HomeBuddyLeaderboardPresentation.TagInput] {
        diveBuddyTags.compactMap { tag in
            guard let diveActivityID = tag.diveActivityID ?? tag.dive?.id,
                  ownerDiveIDs.contains(diveActivityID) else { return nil }
            return tagInput(from: tag, diveActivityID: diveActivityID)
        }
    }

    @MainActor
    private static func tagInput(
        from tag: DiveBuddyTag,
        diveActivityID: UUID
    ) -> HomeBuddyLeaderboardPresentation.TagInput? {
        guard let buddyID = tag.buddyID ?? tag.buddy?.id else { return nil }
        return HomeBuddyLeaderboardPresentation.TagInput(
            buddyID: buddyID,
            displayName: tag.displayName,
            profilePhoto: tag.buddy?.profilePhoto,
            diveActivityID: diveActivityID
        )
    }

    @MainActor
    static func mergedTagInputs(
        _ sources: [HomeBuddyLeaderboardPresentation.TagInput]...
    ) -> [HomeBuddyLeaderboardPresentation.TagInput] {
        var seen: Set<String> = []
        var merged: [HomeBuddyLeaderboardPresentation.TagInput] = []
        for source in sources {
            for tag in source {
                let key = "\(tag.buddyID.uuidString)|\(tag.diveActivityID.uuidString)"
                guard seen.insert(key).inserted else { continue }
                merged.append(tag)
            }
        }
        return merged
    }
}
