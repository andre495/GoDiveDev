import Foundation
import SwiftData

/// One-shot republish so existing friend shares pick up dive **`profileTrackBase64`** and snorkel **`swimTrackBase64`**.
enum GoDiveFriendShareProfileTrackRepublish: Sendable {
    nonisolated static let completedDefaultsKey = "godive.friendShareProfileTrackRepublish.v3.completed"

    @MainActor
    static func scheduleOneTimeRepublishIfNeeded(
        ownerProfileID: UUID,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) {
        guard AppUserSettings.shareDivesWithFriends(userDefaults: userDefaults) else { return }
        guard !userDefaults.bool(forKey: completedDefaultsKey) else { return }
        userDefaults.set(true, forKey: completedDefaultsKey)
        GoDiveFriendShareRefreshCoordinator.scheduleRepublish(
            ownerProfileID: ownerProfileID,
            modelContext: modelContext
        )
    }

    nonisolated static func resetCompletedFlag(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: completedDefaultsKey)
    }
}
