import Foundation

/// Payload keys, copy, and tap routing for **buddy commented on your activity** pushes.
/// Server counterpart: `notifyBuddyActivityCommented` in `catalog-cdn/functions/index.js`.
enum GoDiveBuddyActivityCommentedPushPresentation: Sendable {
    nonisolated static let notificationType = "buddy_activity_commented"
    nonisolated static let friendUIDKey = "friendUID"
    nonisolated static let activityIDKey = "activityID"
    nonisolated static let activityKindKey = "activityKind"
    /// Comment snippet in the APNs body — keep in sync with **`BUDDY_ACTIVITY_COMMENT_PREVIEW_MAX_CHARS`**.
    nonisolated static let commentPreviewMaxCharacters = 50

    /// Tap target — open the owner's own dive/snorkel that was commented on.
    struct Target: Equatable, Sendable {
        var authorUID: String
        var activityID: UUID
        var activityKind: FriendSharedActivityKind
    }

    nonisolated static func target(fromUserInfo userInfo: [AnyHashable: Any]) -> Target? {
        guard (userInfo["type"] as? String) == notificationType else { return nil }
        guard let authorUID = trimmedNonEmpty(userInfo[friendUIDKey] as? String) else { return nil }
        guard let activityRaw = trimmedNonEmpty(userInfo[activityIDKey] as? String),
              let activityID = UUID(uuidString: activityRaw)
        else { return nil }
        let kindRaw = trimmedNonEmpty(userInfo[activityKindKey] as? String) ?? ""
        let kind = FriendSharedActivityKind(rawValue: kindRaw) ?? .scubaDive
        return Target(authorUID: authorUID, activityID: activityID, activityKind: kind)
    }

    nonisolated static func notificationTitle() -> String {
        "New comment on your activity"
    }

    /// Copy parity with the Cloud Function.
    nonisolated static func notificationBody(
        authorDisplayName: String,
        activityKind: FriendSharedActivityKind,
        commentText: String? = nil
    ) -> String {
        let name = authorDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = name.isEmpty ? "A dive buddy" : name
        let kind = activityKind == .snorkel ? "snorkel" : "dive"
        if let preview = commentNotificationPreview(commentText), !preview.isEmpty {
            return "\(label) commented on your \(kind): \(preview)"
        }
        return "\(label) commented on your \(kind)."
    }

    /// Collapse whitespace and truncate for the push body (parity with CF).
    nonisolated static func commentNotificationPreview(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let collapsed = raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        let maxChars = commentPreviewMaxCharacters
        if collapsed.count <= maxChars {
            return collapsed
        }
        guard maxChars > 1 else { return "…" }
        let end = collapsed.index(collapsed.startIndex, offsetBy: maxChars - 1)
        return String(collapsed[..<end]) + "…"
    }

    nonisolated static func logbookRoute(for target: Target) -> LogbookRoute {
        switch target.activityKind {
        case .scubaDive:
            .diveDetail(target.activityID)
        case .snorkel:
            .snorkelDetail(target.activityID)
        }
    }

    /// Maps into the shared owned-activity push navigation store (same deep link as likes).
    nonisolated static func likedPushCompatibleTarget(
        for target: Target
    ) -> GoDiveBuddyActivityLikedPushPresentation.Target {
        GoDiveBuddyActivityLikedPushPresentation.Target(
            likerUID: target.authorUID,
            activityID: target.activityID,
            activityKind: target.activityKind
        )
    }

    nonisolated private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}
