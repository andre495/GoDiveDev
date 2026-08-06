import Foundation

/// Payload keys, copy, and tap routing for **mentioned in a comment** pushes.
/// Server counterpart: `notifyBuddyActivityCommented` mention branch in `catalog-cdn/functions/index.js`.
enum GoDiveBuddyActivityMentionedPushPresentation: Sendable {
    nonisolated static let notificationType = "buddy_activity_mentioned"
    nonisolated static let friendUIDKey = "friendUID"
    nonisolated static let activityIDKey = "activityID"
    nonisolated static let activityKindKey = "activityKind"
    nonisolated static let ownerUIDKey = "ownerUID"

    /// Tap target — open the activity (owned or friend-shared) with comments.
    struct Target: Equatable, Sendable {
        var authorUID: String
        var ownerUID: String
        var activityID: UUID
        var activityKind: FriendSharedActivityKind
    }

    nonisolated static func target(fromUserInfo userInfo: [AnyHashable: Any]) -> Target? {
        guard (userInfo["type"] as? String) == notificationType else { return nil }
        guard let authorUID = trimmedNonEmpty(userInfo[friendUIDKey] as? String) else { return nil }
        guard let ownerUID = trimmedNonEmpty(userInfo[ownerUIDKey] as? String) else { return nil }
        guard let activityRaw = trimmedNonEmpty(userInfo[activityIDKey] as? String),
              let activityID = UUID(uuidString: activityRaw)
        else { return nil }
        let kindRaw = trimmedNonEmpty(userInfo[activityKindKey] as? String) ?? ""
        let kind = FriendSharedActivityKind(rawValue: kindRaw) ?? .scubaDive
        return Target(
            authorUID: authorUID,
            ownerUID: ownerUID,
            activityID: activityID,
            activityKind: kind
        )
    }

    nonisolated static func notificationTitle() -> String {
        "Mentioned in a comment"
    }

    nonisolated static func notificationBody(
        authorDisplayName: String,
        commentText: String? = nil
    ) -> String {
        let name = authorDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = name.isEmpty ? "A dive buddy" : name
        if let preview = GoDiveBuddyActivityCommentedPushPresentation.commentNotificationPreview(
            commentText
        ), !preview.isEmpty {
            return "\(label) mentioned you in a comment: \(preview)"
        }
        return "\(label) mentioned you in a comment."
    }

    /// Whether the recipient should open their own Logbook detail (vs friend-shared).
    nonisolated static func isOwnedActivity(
        target: Target,
        currentFirebaseUID: String?
    ) -> Bool {
        let me = currentFirebaseUID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !me.isEmpty else { return false }
        return target.ownerUID == me
    }

    nonisolated static func ownedLogbookRoute(for target: Target) -> LogbookRoute {
        switch target.activityKind {
        case .scubaDive:
            .diveDetail(target.activityID)
        case .snorkel:
            .snorkelDetail(target.activityID)
        }
    }

    nonisolated static func sharedLogbookRoute(for target: Target) -> LogbookRoute {
        .buddySharedDive(
            friendUID: target.ownerUID,
            diveDocumentID: target.activityID.uuidString,
            opensComments: true
        )
    }

    nonisolated private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}

/// Holds a mention-push tap target while the app cold-launches.
@MainActor
final class GoDiveBuddyActivityMentionedPushNavigationStore {
    static let shared = GoDiveBuddyActivityMentionedPushNavigationStore()

    private(set) var pendingTarget: GoDiveBuddyActivityMentionedPushPresentation.Target?

    private init() {}

    func setPending(_ target: GoDiveBuddyActivityMentionedPushPresentation.Target) {
        pendingTarget = target
    }

    func consumePendingTarget() -> GoDiveBuddyActivityMentionedPushPresentation.Target? {
        let target = pendingTarget
        pendingTarget = nil
        return target
    }

    func clear() {
        pendingTarget = nil
    }
}
