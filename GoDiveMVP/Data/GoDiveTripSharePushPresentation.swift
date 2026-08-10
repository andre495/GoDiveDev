import Foundation

/// FCM payload + navigation for trip-share invites.
enum GoDiveTripSharePushPresentation: Sendable {
    nonisolated static let notificationType = "trip_share_invite"

    struct Target: Equatable, Sendable, Hashable {
        var inviteID: String
        var sharerUID: String
        var tripID: String
        var title: String?
    }

    nonisolated static func target(fromUserInfo userInfo: [AnyHashable: Any]) -> Target? {
        let type = (userInfo["type"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard type == notificationType else { return nil }
        guard let inviteID = trimmed(userInfo["inviteId"] as? String),
              let sharerUID = trimmed(userInfo["sharerUid"] as? String),
              let tripID = trimmed(userInfo["tripId"] as? String)
        else { return nil }
        return Target(
            inviteID: inviteID,
            sharerUID: sharerUID,
            tripID: tripID,
            title: trimmed(userInfo["title"] as? String)
        )
    }

    nonisolated static let openTripShareInviteNotification = Notification.Name(
        "GoDiveOpenTripShareInviteNotification"
    )

    nonisolated private static func trimmed(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

@MainActor
final class GoDiveTripSharePushNavigationStore {
    static let shared = GoDiveTripSharePushNavigationStore()

    private(set) var pending: GoDiveTripSharePushPresentation.Target?

    func setPending(_ target: GoDiveTripSharePushPresentation.Target) {
        pending = target
    }

    func consumePending() -> GoDiveTripSharePushPresentation.Target? {
        let value = pending
        pending = nil
        return value
    }

    func clear() {
        pending = nil
    }
}
