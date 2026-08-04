import Foundation

/// After a successful dive/snorkel delete: return to Logbook and show a brief checkmark.
enum ActivityDeleteSuccessPresentation: Sendable {
    nonisolated static let overlayDuration: Duration = .seconds(1)

    nonisolated static let checkmarkAccessibilityLabel = "Activity deleted"

    nonisolated static let didDeleteNotification = Notification.Name("GoDive.activityDidDeleteSuccessfully")

    nonisolated static let activityIDUserInfoKey = "activityID"

    @MainActor
    static func postDidDelete(activityID: UUID) {
        NotificationCenter.default.post(
            name: didDeleteNotification,
            object: nil,
            userInfo: [activityIDUserInfoKey: activityID]
        )
    }

    nonisolated static func activityID(from notification: Notification) -> UUID? {
        notification.userInfo?[activityIDUserInfoKey] as? UUID
    }

    /// Drops logbook routes that open the deleted activity (detail / media focus).
    nonisolated static func logbookPathByRemovingActivity(
        _ path: [LogbookRoute],
        activityID: UUID
    ) -> [LogbookRoute] {
        path.filter { route in
            switch route {
            case .diveDetail(let id), .snorkelDetail(let id), .diveMedia(let id, _), .snorkelMedia(let id, _):
                return id != activityID
            default:
                return true
            }
        }
    }

    nonisolated static func homePathByRemovingActivity(
        _ path: [HomeRoute],
        activityID: UUID
    ) -> [HomeRoute] {
        path.filter { route in
            switch route {
            case .diveDetail(let id), .diveMedia(diveID: let id, mediaID: _):
                return id != activityID
            default:
                return true
            }
        }
    }

    nonisolated static func explorePathByRemovingActivity(
        _ path: [ExploreRoute],
        activityID: UUID
    ) -> [ExploreRoute] {
        path.filter { route in
            if case .diveDetail(let id) = route {
                return id != activityID
            }
            return true
        }
    }

    nonisolated static func searchPathByRemovingActivity(
        _ path: [GlobalSearchPresentation.Destination],
        activityID: UUID
    ) -> [GlobalSearchPresentation.Destination] {
        path.filter { destination in
            if case .dive(let id) = destination {
                return id != activityID
            }
            return true
        }
    }
}
