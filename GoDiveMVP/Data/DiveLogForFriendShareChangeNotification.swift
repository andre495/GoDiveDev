import Foundation

extension Notification.Name {
    /// Posted when local dive log rows that may need friend-share projection refresh change.
    nonisolated static let diveLogForFriendShareDidChange = Notification.Name(
        "GoDive.diveLogForFriendShareDidChange"
    )
}

enum DiveLogForFriendShareChangeNotification {
    nonisolated static let diveIDUserInfoKey = "diveID"

    /// Posts a change. Pass **`diveID`** to upsert one dive; omit for a full republish.
    nonisolated static func post(diveID: UUID? = nil) {
        var userInfo: [AnyHashable: Any] = [:]
        if let diveID {
            userInfo[diveIDUserInfoKey] = diveID
        }
        NotificationCenter.default.post(
            name: .diveLogForFriendShareDidChange,
            object: nil,
            userInfo: userInfo.isEmpty ? nil : userInfo
        )
    }

    nonisolated static func diveID(from notification: Notification) -> UUID? {
        notification.userInfo?[diveIDUserInfoKey] as? UUID
    }
}
