import Foundation

extension Notification.Name {
    /// Posted after trip ↔ dive links change so **`LogbookView`** can rebuild trip grouping.
    nonisolated static let diveTripLogbookGroupingDidChange =
        Notification.Name("GoDive.diveTripLogbookGroupingDidChange")
}

/// Notifies the logbook to refresh trip group chrome when trips or links change.
enum DiveTripLogbookSync: Sendable {

    nonisolated static func notifyGroupingDidChange() {
        // Defer one turn so SwiftData `@Query` merges before **`LogbookView`** rebuilds trip seeds.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .diveTripLogbookGroupingDidChange, object: nil)
        }
    }
}
