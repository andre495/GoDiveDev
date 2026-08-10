import Foundation

/// Loads buddy-shared activities for trip detail (network fetch, one UI apply).
enum TripDetailBuddyActivitiesFetch: Sendable {

    @MainActor
    static func loadRows(
        for trip: DiveTrip
    ) async -> [LogbookBuddyFeedPresentation.Row] {
        let planned = DiveTripPlannedBuddyLinking.plannedBuddies(for: trip)
        let friendUIDs = TripDetailBuddyActivitiesPresentation.friendUIDsOnTrip(
            plannedBuddies: planned,
            sharedFromFirebaseUID: trip.sharedFromFirebaseUID
        )
        guard !friendUIDs.isEmpty else { return [] }

        let tripStart = trip.startDate
        let tripEnd = trip.endDate

        // Snapshot friend edges for display names / photos.
        let friends = ((try? await GoDiveFriendGraphService.listFriendEdges()) ?? [])
            .filter { friendUIDs.contains($0.friendUID) }
        var friendByUID = Dictionary(uniqueKeysWithValues: friends.map { ($0.friendUID, $0) })
        for buddy in planned {
            guard let uid = DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: buddy) else {
                continue
            }
            if friendByUID[uid] == nil {
                friendByUID[uid] = GoDiveFriendGraphService.friendEdge(
                    friendUID: uid,
                    displayName: buddy.displayName,
                    photoURL: buddy.linkedPhotoURL
                )
            }
        }
        // Ensure sharer appears even if not in planned roster yet.
        if let sharer = trip.sharedFromFirebaseUID?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !sharer.isEmpty,
           friendByUID[sharer] == nil {
            let profile = await GoDiveFriendGraphService.fetchPublicProfile(uid: sharer)
            friendByUID[sharer] = GoDiveFriendGraphService.friendEdge(
                friendUID: sharer,
                displayName: profile?.displayName ?? "Dive buddy",
                photoURL: profile?.photoURL
            )
        }

        let orderedFriends = friendUIDs.compactMap { friendByUID[$0] }
        guard !orderedFriends.isEmpty else { return [] }

        var divesByFriendUID: [String: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive]] = [:]
        divesByFriendUID.reserveCapacity(orderedFriends.count)
        await withTaskGroup(of: (String, [GoDiveSharedDiveProjectionMapping.FriendVisibleDive]).self) { group in
            for friend in orderedFriends {
                let uid = friend.friendUID
                group.addTask {
                    let dives = await GoDiveSharedDiveProjectionSync.fetchFriendSharedDives(friendUID: uid)
                    return (uid, dives)
                }
            }
            for await (uid, dives) in group {
                divesByFriendUID[uid] = dives
            }
        }

        let baseRows = LogbookBuddyFeedPresentation.rows(
            friends: orderedFriends,
            divesByFriendUID: divesByFriendUID
        )
        return TripDetailBuddyActivitiesPresentation.rowsInTripWindow(
            baseRows,
            start: tripStart,
            end: tripEnd
        )
    }
}
