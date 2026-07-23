import Foundation

extension Notification.Name {
    /// Posted when the Firestore friend graph changes (redeem, unfriend, etc.).
    nonisolated static let goDiveFriendGraphDidChange = Notification.Name(
        "GoDive.friendGraphDidChange"
    )
}

enum GoDiveFriendGraphChangeNotification {
    nonisolated static func post() {
        NotificationCenter.default.post(name: .goDiveFriendGraphDidChange, object: nil)
    }
}
