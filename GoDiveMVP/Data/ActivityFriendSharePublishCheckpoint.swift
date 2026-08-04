import Foundation
import SwiftData

/// Strava-style publish checkpoint: new activities stay **local-only** until the owner taps
/// **Share** (publish to the buddy network) or **Keep local** on the detail-page banner.
/// Publishing flips the per-activity share flag and schedules the Firestore projection upsert,
/// which in turn fires the buddy push signal on first create.
enum ActivityFriendSharePublishCheckpoint: Sendable {

    /// Pure visibility rule for the banner — testable without SwiftData models.
    nonisolated static func showsBanner(
        checkpointPending: Bool,
        settingsConfigured: Bool,
        globalSharingEnabled: Bool
    ) -> Bool {
        checkpointPending && !settingsConfigured && globalSharingEnabled
    }

    // MARK: - Dive

    @MainActor
    static func isPending(dive: DiveActivity, userDefaults: UserDefaults = .standard) -> Bool {
        showsBanner(
            checkpointPending: dive.friendSharePublishCheckpointPending,
            settingsConfigured: dive.friendShareBuddySettingsConfigured,
            globalSharingEnabled: AppUserSettings.shareDivesWithFriends(userDefaults: userDefaults)
        )
    }

    /// One-tap publish: share on, media/notes from the seeded snapshot defaults.
    @MainActor
    static func publish(
        dive: DiveActivity,
        ownerProfileID: UUID?,
        modelContext: ModelContext
    ) {
        ActivityFriendShareConfiguration.applyConfiguredSettings(
            to: dive,
            shareActivityEnabled: true,
            shareMediaEnabled: dive.friendShareMediaEnabled,
            selectedMediaIDs: publishSelectedMediaIDs(
                mediaEnabled: dive.friendShareMediaEnabled,
                galleryIDs: DiveActivityMediaPresentation.sortedPhotos(on: dive).map(\.id)
            ),
            notesMode: ActivityFriendShareNotesMode(rawValue: dive.friendShareNotesModeRaw) ?? .off,
            publicNotes: dive.friendSharePublicNotes
        )
        try? modelContext.save()
        guard let ownerProfileID else { return }
        GoDiveFriendShareRefreshCoordinator.scheduleUpsert(
            diveIDs: [dive.id],
            ownerProfileID: ownerProfileID,
            modelContext: modelContext
        )
    }

    @MainActor
    static func keepLocal(dive: DiveActivity, modelContext: ModelContext) {
        ActivityFriendShareConfiguration.applyConfiguredSettings(
            to: dive,
            shareActivityEnabled: false,
            shareMediaEnabled: false,
            selectedMediaIDs: ActivityFriendShareConfiguration.selectedMediaIDs(on: dive),
            notesMode: ActivityFriendShareNotesMode(rawValue: dive.friendShareNotesModeRaw) ?? .off,
            publicNotes: dive.friendSharePublicNotes
        )
        try? modelContext.save()
    }

    // MARK: - Snorkel

    @MainActor
    static func isPending(snorkel: SnorkelActivity, userDefaults: UserDefaults = .standard) -> Bool {
        showsBanner(
            checkpointPending: snorkel.friendSharePublishCheckpointPending,
            settingsConfigured: snorkel.friendShareBuddySettingsConfigured,
            globalSharingEnabled: AppUserSettings.shareDivesWithFriends(userDefaults: userDefaults)
        )
    }

    @MainActor
    static func publish(
        snorkel: SnorkelActivity,
        ownerProfileID: UUID?,
        modelContext: ModelContext
    ) {
        ActivityFriendShareConfiguration.applyConfiguredSettings(
            to: snorkel,
            shareActivityEnabled: true,
            shareMediaEnabled: snorkel.friendShareMediaEnabled,
            selectedMediaIDs: publishSelectedMediaIDs(
                mediaEnabled: snorkel.friendShareMediaEnabled,
                galleryIDs: SnorkelActivityMediaPresentation.sortedPhotos(snorkel.mediaPhotos).map(\.id)
            ),
            notesMode: ActivityFriendShareNotesMode(rawValue: snorkel.friendShareNotesModeRaw) ?? .off,
            publicNotes: snorkel.friendSharePublicNotes
        )
        try? modelContext.save()
        guard let ownerProfileID else { return }
        GoDiveFriendShareRefreshCoordinator.scheduleUpsert(
            diveIDs: [snorkel.id],
            ownerProfileID: ownerProfileID,
            modelContext: modelContext
        )
    }

    @MainActor
    static func keepLocal(snorkel: SnorkelActivity, modelContext: ModelContext) {
        ActivityFriendShareConfiguration.applyConfiguredSettings(
            to: snorkel,
            shareActivityEnabled: false,
            shareMediaEnabled: false,
            selectedMediaIDs: ActivityFriendShareConfiguration.selectedMediaIDs(on: snorkel),
            notesMode: ActivityFriendShareNotesMode(rawValue: snorkel.friendShareNotesModeRaw) ?? .off,
            publicNotes: snorkel.friendSharePublicNotes
        )
        try? modelContext.save()
    }

    // MARK: - Private

    /// When the seeded media default is on, one-tap publish shares the full gallery
    /// (matching the pre-first-save inheritance in the Activity Settings grid).
    nonisolated static func publishSelectedMediaIDs(
        mediaEnabled: Bool,
        galleryIDs: [UUID]
    ) -> Set<UUID> {
        mediaEnabled ? Set(galleryIDs) : []
    }
}
