import Foundation

/// FCM payload when a recipient accepts a trip-share invite (notifies the sharer).
enum GoDiveTripShareInviteAcceptedPushPresentation: Sendable {
    nonisolated static let notificationType = "trip_share_invite_accepted"

    struct Target: Equatable, Sendable, Hashable {
        var tripID: UUID
        var friendUID: String
        var inviteID: String?
        var title: String?
    }

    nonisolated static func target(fromUserInfo userInfo: [AnyHashable: Any]) -> Target? {
        let type = (userInfo["type"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard type == notificationType else { return nil }
        guard let tripRaw = trimmed(userInfo["tripId"] as? String),
              let tripID = UUID(uuidString: tripRaw),
              let friendUID = trimmed(userInfo["friendUID"] as? String)
        else { return nil }
        return Target(
            tripID: tripID,
            friendUID: friendUID,
            inviteID: trimmed(userInfo["inviteId"] as? String),
            title: trimmed(userInfo["title"] as? String)
        )
    }

    nonisolated static func notificationTitle() -> String {
        "Trip buddy joined"
    }

    nonisolated static func notificationBody(
        friendDisplayName: String,
        tripTitle: String
    ) -> String {
        let name = friendDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = name.isEmpty ? "A buddy" : name
        let trip = tripTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let tripLabel = trip.isEmpty ? "your trip" : trip
        return "\(label) joined \(tripLabel)!"
    }

    nonisolated static let openTripShareAcceptedNotification = Notification.Name(
        "GoDiveOpenTripShareAcceptedNotification"
    )

    nonisolated private static func trimmed(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Pure trigger for Cloud Functions / tests.
enum GoDiveTripShareInviteAcceptedPushTrigger: Sendable {
    nonisolated static func shouldNotify(
        beforeStatus: String?,
        afterStatus: String?
    ) -> Bool {
        guard afterStatus == GoDiveTripShareMapping.InviteStatus.accepted.rawValue else {
            return false
        }
        guard beforeStatus == GoDiveTripShareMapping.InviteStatus.pending.rawValue else {
            return false
        }
        return beforeStatus != afterStatus
    }
}

@MainActor
final class GoDiveTripShareInviteAcceptedPushNavigationStore {
    static let shared = GoDiveTripShareInviteAcceptedPushNavigationStore()

    private(set) var pending: GoDiveTripShareInviteAcceptedPushPresentation.Target?

    func setPending(_ target: GoDiveTripShareInviteAcceptedPushPresentation.Target) {
        pending = target
    }

    func consumePending() -> GoDiveTripShareInviteAcceptedPushPresentation.Target? {
        let value = pending
        pending = nil
        return value
    }

    func clear() {
        pending = nil
    }
}
