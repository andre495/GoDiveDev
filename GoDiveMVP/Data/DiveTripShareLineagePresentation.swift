import Foundation

/// Invitee-copy lineage + edit locks for trip-share duplicates.
enum DiveTripShareLineagePresentation: Sendable {
    enum Status: String, Sendable, Equatable {
        case pending
        case accepted
    }

    nonisolated static func status(of trip: DiveTrip) -> Status? {
        guard let raw = trip.tripShareStatusRaw?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else { return nil }
        return Status(rawValue: raw)
    }

    nonisolated static func isSharedInviteeCopy(_ trip: DiveTrip) -> Bool {
        let source = trip.sharedTripSourceID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sharer = trip.sharedFromFirebaseUID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !source.isEmpty && !sharer.isEmpty && status(of: trip) != nil
    }

    /// Only the original creator (non-invitee) may edit synced trip details.
    nonisolated static func canEditSharedDetails(_ trip: DiveTrip) -> Bool {
        !isSharedInviteeCopy(trip)
    }

    nonisolated static func isPendingInvite(_ trip: DiveTrip) -> Bool {
        status(of: trip) == .pending
    }

    nonisolated static func isAcceptedInvite(_ trip: DiveTrip) -> Bool {
        status(of: trip) == .accepted
    }

    nonisolated static func hasSharedWithFriend(_ trip: DiveTrip, friendUID: String) -> Bool {
        let uid = friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return false }
        return trip.sharedWithFriendUIDs.contains { $0 == uid }
    }

    nonisolated static func recordSharedWithFriend(_ trip: DiveTrip, friendUID: String) {
        let uid = friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return }
        var uids = trip.sharedWithFriendUIDs
        guard !uids.contains(uid) else { return }
        uids.append(uid)
        trip.sharedWithFriendUIDs = uids
    }

    nonisolated static func removeSharedWithFriend(_ trip: DiveTrip, friendUID: String) {
        let uid = friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return }
        trip.sharedWithFriendUIDs = trip.sharedWithFriendUIDs.filter { $0 != uid }
        removeAcceptedFriend(trip, friendUID: uid)
    }

    nonisolated static func hasAcceptedFriend(_ trip: DiveTrip, friendUID: String) -> Bool {
        let uid = friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return false }
        return trip.tripShareAcceptedFriendUIDs.contains { $0 == uid }
    }

    nonisolated static func recordAcceptedFriend(_ trip: DiveTrip, friendUID: String) {
        let uid = friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return }
        var uids = trip.tripShareAcceptedFriendUIDs
        guard !uids.contains(uid) else { return }
        uids.append(uid)
        trip.tripShareAcceptedFriendUIDs = uids
        // Accept implies share was offered.
        recordSharedWithFriend(trip, friendUID: uid)
    }

    nonisolated static func removeAcceptedFriend(_ trip: DiveTrip, friendUID: String) {
        let uid = friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return }
        trip.tripShareAcceptedFriendUIDs = trip.tripShareAcceptedFriendUIDs.filter { $0 != uid }
    }
}
