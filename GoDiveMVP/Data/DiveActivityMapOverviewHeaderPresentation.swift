import CoreGraphics
import Foundation

enum DiveActivityMapOverviewHeaderPresentation: Sendable {
    nonisolated static let buddyOwnerAvatarDiameter: CGFloat = 28

    nonisolated static func usesBuddyOwnerLayout(sharedByDisplayName: String?) -> Bool {
        let trimmed = sharedByDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !trimmed.isEmpty
    }
}
