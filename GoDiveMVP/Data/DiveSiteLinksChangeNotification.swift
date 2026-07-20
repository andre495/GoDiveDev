import Foundation

extension Notification.Name {
    /// Posted after dive ↔ site links change (import reuse, duplicate site consolidation).
    nonisolated static let diveSiteLinksDidChange = Notification.Name("GoDive.diveSiteLinksDidChange")
}

enum DiveSiteLinksChangeNotification {
    nonisolated static func post() {
        NotificationCenter.default.post(name: .diveSiteLinksDidChange, object: nil)
    }
}
