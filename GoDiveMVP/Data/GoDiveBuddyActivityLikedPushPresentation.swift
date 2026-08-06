import Foundation

/// Payload keys, copy, and tap routing for **buddy liked your activity** pushes.
/// Server counterpart: `notifyBuddyActivityLiked` in `catalog-cdn/functions/index.js`.
enum GoDiveBuddyActivityLikedPushPresentation: Sendable {
    nonisolated static let notificationType = "buddy_activity_liked"
    nonisolated static let friendUIDKey = "friendUID"
    nonisolated static let activityIDKey = "activityID"
    nonisolated static let activityKindKey = "activityKind"

    /// Tap target — open the owner's own dive/snorkel that was liked.
    struct Target: Equatable, Sendable {
        var likerUID: String
        var activityID: UUID
        var activityKind: FriendSharedActivityKind
    }

    nonisolated static func target(fromUserInfo userInfo: [AnyHashable: Any]) -> Target? {
        guard (userInfo["type"] as? String) == notificationType else { return nil }
        guard let likerUID = trimmedNonEmpty(userInfo[friendUIDKey] as? String) else { return nil }
        guard let activityRaw = trimmedNonEmpty(userInfo[activityIDKey] as? String),
              let activityID = UUID(uuidString: activityRaw)
        else { return nil }
        let kindRaw = trimmedNonEmpty(userInfo[activityKindKey] as? String) ?? ""
        let kind = FriendSharedActivityKind(rawValue: kindRaw) ?? .scubaDive
        return Target(likerUID: likerUID, activityID: activityID, activityKind: kind)
    }

    nonisolated static func notificationTitle() -> String {
        "Someone liked your activity"
    }

    /// Copy parity with the Cloud Function.
    nonisolated static func notificationBody(
        likerDisplayName: String,
        activityKind: FriendSharedActivityKind
    ) -> String {
        let name = likerDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = name.isEmpty ? "A dive buddy" : name
        let kind = activityKind == .snorkel ? "snorkel" : "dive"
        return "\(label) liked your \(kind)."
    }

    nonisolated static func logbookRoute(for target: Target) -> LogbookRoute {
        switch target.activityKind {
        case .scubaDive:
            .diveDetail(target.activityID)
        case .snorkel:
            .snorkelDetail(target.activityID)
        }
    }

    nonisolated private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}

/// Holds the like-push tap target while the app cold-launches.
@MainActor
final class GoDiveBuddyActivityLikedPushNavigationStore {
    static let shared = GoDiveBuddyActivityLikedPushNavigationStore()

    private(set) var pendingTarget: GoDiveBuddyActivityLikedPushPresentation.Target?

    private init() {}

    func setPending(_ target: GoDiveBuddyActivityLikedPushPresentation.Target) {
        pendingTarget = target
    }

    func consumePendingTarget() -> GoDiveBuddyActivityLikedPushPresentation.Target? {
        let target = pendingTarget
        pendingTarget = nil
        return target
    }

    func clear() {
        pendingTarget = nil
    }
}
