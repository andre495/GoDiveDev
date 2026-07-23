import Foundation
import SwiftData

/// Nudges SwiftData + CloudKit mirroring as soon as the production user store is attached.
enum GoDiveCloudKitDiveLogSyncKickstart: Sendable {

    /// Lightweight main-context reads so the persistent store coordinator schedules import work early.
    @MainActor
    static func kick(container: ModelContainer, defaults: UserDefaults = .standard) {
        guard GoDiveCloudKitDiveLogLocalStatus.readPrivateSyncState(defaults: defaults) == .enabled else {
            return
        }
        let context = container.mainContext
        context.processPendingChanges()
        _ = try? context.fetchCount(FetchDescriptor<UserProfile>())
        _ = try? context.fetchCount(FetchDescriptor<DiveActivity>())
        _ = try? context.fetchCount(FetchDescriptor<SnorkelActivity>())
    }
}
