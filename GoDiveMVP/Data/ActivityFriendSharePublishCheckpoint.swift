import Foundation
import SwiftData

/// Strava-style publish checkpoint: new activities stay **local-only** until the owner taps
/// **Share** (publish to the buddy network), dismisses the banner, or visits Activity Settings.
/// Publishing flips the per-activity share flag and schedules the Firestore projection upsert,
/// which in turn fires the buddy push signal on first create.
enum ActivityFriendSharePublishCheckpoint: Sendable {

    /// Pure visibility rule for the banner — testable without SwiftData models.
    /// Requires an active buddy network so the prompt is only shown when sharing has recipients.
    nonisolated static func showsBanner(
        checkpointPending: Bool,
        settingsConfigured: Bool,
        globalSharingEnabled: Bool,
        hasFriends: Bool
    ) -> Bool {
        checkpointPending && !settingsConfigured && globalSharingEnabled && hasFriends
    }

    /// Banner sits above the sheet seam only while the overview panel is at **large**.
    nonisolated static func isVisibleInOverviewDetent(_ detent: DiveActivityOverviewDetent) -> Bool {
        detent == .large
    }

    // MARK: - Dive

    @MainActor
    static func isPending(
        dive: DiveActivity,
        hasFriends: Bool,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        showsBanner(
            checkpointPending: dive.friendSharePublishCheckpointPending,
            settingsConfigured: dive.friendShareBuddySettingsConfigured,
            globalSharingEnabled: AppUserSettings.shareDivesWithFriends(userDefaults: userDefaults),
            hasFriends: hasFriends
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

    /// Permanently hides the banner (× or opening Activity Settings) without publishing.
    @MainActor
    static func dismiss(dive: DiveActivity, modelContext: ModelContext) {
        guard dive.friendSharePublishCheckpointPending else { return }
        dive.friendSharePublishCheckpointPending = false
        try? modelContext.save()
    }

    // MARK: - Snorkel

    @MainActor
    static func isPending(
        snorkel: SnorkelActivity,
        hasFriends: Bool,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        showsBanner(
            checkpointPending: snorkel.friendSharePublishCheckpointPending,
            settingsConfigured: snorkel.friendShareBuddySettingsConfigured,
            globalSharingEnabled: AppUserSettings.shareDivesWithFriends(userDefaults: userDefaults),
            hasFriends: hasFriends
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
    static func dismiss(snorkel: SnorkelActivity, modelContext: ModelContext) {
        guard snorkel.friendSharePublishCheckpointPending else { return }
        snorkel.friendSharePublishCheckpointPending = false
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
