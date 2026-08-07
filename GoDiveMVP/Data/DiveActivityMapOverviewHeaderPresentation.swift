import CoreGraphics
import Foundation

enum DiveActivityMapOverviewHeaderPresentation: Sendable {
    nonisolated static let buddyOwnerAvatarDiameter: CGFloat = 28
    nonisolated static let openFriendProfileAccessibilityHint = "Opens friend profile"

    nonisolated static func usesBuddyOwnerLayout(sharedByDisplayName: String?) -> Bool {
        let trimmed = sharedByDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !trimmed.isEmpty
    }

    /// Whether the buddy owner avatar/name should act as a profile control.
    nonisolated static func showsOpenFriendProfileControl(onOpenSharedBy: (() -> Void)?) -> Bool {
        onOpenSharedBy != nil
    }
}
