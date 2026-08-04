import Foundation

/// Payload keys, copy, and tap routing for **buddy activity shared** pushes.
/// Server counterpart: `notifyBuddyActivityShared` in `catalog-cdn/functions/index.js`
/// (20 s batch window per poster + permanent first-share dedupe).
enum GoDiveBuddyActivityPushPresentation: Sendable {
    nonisolated static let notificationType = "buddy_activity_shared"
    nonisolated static let friendUIDKey = "friendUID"
    nonisolated static let activityIDKey = "activityID"
    nonisolated static let activityCountKey = "activityCount"

    /// Firestore doc `users/{uid}/private/notificationPrefs` read by the Cloud Function.
    nonisolated static let notificationPrefsDocumentID = "notificationPrefs"
    nonisolated static let buddyActivitySharesEnabledField = "buddyActivitySharesEnabled"

    /// Tap target parsed from the push payload — friend's UID plus the shared
    /// activity document to open (latest in the series for batched pushes).
    struct Target: Equatable, Sendable {
        var friendUID: String
        var activityID: String
    }

    nonisolated static func target(fromUserInfo userInfo: [AnyHashable: Any]) -> Target? {
        guard (userInfo["type"] as? String) == notificationType else { return nil }
        guard let friendUID = trimmedNonEmpty(userInfo[friendUIDKey] as? String) else { return nil }
        guard let activityID = trimmedNonEmpty(userInfo[activityIDKey] as? String) else { return nil }
        return Target(friendUID: friendUID, activityID: activityID)
    }

    /// Copy parity with the Cloud Function (single dive / single snorkel / batch).
    nonisolated static func notificationBody(
        posterDisplayName: String,
        activityCount: Int,
        singleActivityKind: FriendSharedActivityKind
    ) -> String {
        let name = posterDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = name.isEmpty ? "A dive buddy" : name
        if activityCount <= 1 {
            let kind = singleActivityKind == .snorkel ? "snorkel" : "dive"
            return "\(label) logged a new \(kind)."
        }
        return "\(label) shared \(activityCount) new activities."
    }

    /// When the recipient is tagged on the shared activity (or activities in a batch).
    nonisolated static func taggedYouNotificationBody(
        posterDisplayName: String,
        taggedActivityCount: Int,
        singleActivityKind: FriendSharedActivityKind
    ) -> String {
        let name = posterDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = name.isEmpty ? "A dive buddy" : name
        if taggedActivityCount <= 1 {
            let kind = singleActivityKind == .snorkel ? "snorkel" : "dive"
            return "\(label) tagged you in a new \(kind)."
        }
        return "\(label) tagged you in \(taggedActivityCount) new activities."
    }

    nonisolated static func taggedYouNotificationTitle(taggedActivityCount: Int) -> String {
        taggedActivityCount > 1 ? "Tagged in buddy activities" : "Tagged in a buddy activity"
    }

    nonisolated static func notificationTitle(activityCount: Int) -> String {
        activityCount > 1 ? "New buddy activities" : "New buddy activity"
    }

    /// Parity with `shouldNotifyBuddyActivityShare` in `catalog-cdn/functions/index.js`.
    nonisolated static func shouldNotifyFirstShareableProjection(
        beforeActivityKindRaw: String?,
        afterActivityKindRaw: String?
    ) -> Bool {
        guard let after = afterActivityKindRaw,
              FriendSharedActivityKind(rawValue: after) != nil
        else { return false }
        guard let before = beforeActivityKindRaw else { return true }
        return FriendSharedActivityKind(rawValue: before) == nil
    }

    /// Mirrors the server's pick of which activity a batched push should open:
    /// latest dive start time, later queue position winning ties.
    nonisolated static func latestActivityID(
        from activities: [(id: String, startTime: Date?)]
    ) -> String? {
        var latest: (id: String, startTime: Date?)?
        for activity in activities {
            guard let current = latest else {
                latest = activity
                continue
            }
            let activityStart = activity.startTime ?? .distantPast
            let currentStart = current.startTime ?? .distantPast
            if activityStart >= currentStart {
                latest = activity
            }
        }
        return latest?.id
    }

    nonisolated private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}

/// Holds the tap target while the app cold-launches so the main shell can
/// route Logbook → Buddy Feed → activity detail once it is mounted.
@MainActor
final class GoDiveBuddyActivityPushNavigationStore {
    static let shared = GoDiveBuddyActivityPushNavigationStore()

    private(set) var pendingTarget: GoDiveBuddyActivityPushPresentation.Target?

    private init() {}

    func setPending(_ target: GoDiveBuddyActivityPushPresentation.Target) {
        pendingTarget = target
    }

    func consumePendingTarget() -> GoDiveBuddyActivityPushPresentation.Target? {
        let target = pendingTarget
        pendingTarget = nil
        return target
    }

    func clear() {
        pendingTarget = nil
    }
}
