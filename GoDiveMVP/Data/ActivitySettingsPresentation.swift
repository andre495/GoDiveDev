import Foundation

/// Copy for per-activity **Activity Settings** (buddy sharing + delete).
enum ActivitySettingsPresentation: Sendable {
    static let pageTitle = "Activity Settings"

    static func deleteButtonTitle(activityKind: FriendSharedActivityKind) -> String {
        switch activityKind {
        case .scubaDive:
            return "Delete dive"
        case .snorkel:
            return "Delete snorkel"
        }
    }

    static func deleteConfirmationTitle(activityKind: FriendSharedActivityKind) -> String {
        switch activityKind {
        case .scubaDive:
            return "Delete dive?"
        case .snorkel:
            return "Delete snorkel?"
        }
    }

    static let deleteConfirmationMessage =
        "This permanently removes the activity from your log, including tags, buddies, marine life sightings, and any friend-shared copies. This cannot be undone."

    static func deleteProgressAccessibilityLabel(activityKind: FriendSharedActivityKind) -> String {
        switch activityKind {
        case .scubaDive:
            return "Deleting dive"
        case .snorkel:
            return "Deleting snorkel"
        }
    }

    static let deleteFailedAlertTitle = "Could not delete activity"
}
