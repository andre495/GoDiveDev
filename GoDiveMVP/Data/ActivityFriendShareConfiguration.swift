import Foundation

/// Per-activity friend-share settings resolution (dives + snorkels).
///
/// **Unconfigured activities** use snapshotted global Settings defaults captured at creation (or on
/// first launch backfill). Later global Settings changes apply only to **new** activities. **Configured
/// activities** (**`friendShareBuddySettingsConfigured`**) use only their stored per-activity fields.
enum ActivityFriendShareConfiguration: Sendable {

    /// Global Settings defaults used when seeding or displaying an unconfigured activity.
    struct GlobalDefaults: Equatable, Sendable {
        var shareActivity: Bool
        var shareMedia: Bool
        var notesMode: ActivityFriendShareNotesMode
    }

    nonisolated static func globalDefaults(userDefaults: UserDefaults = .standard) -> GlobalDefaults {
        let shareActivity = AppUserSettings.shareDivesWithFriends(userDefaults: userDefaults)
        return GlobalDefaults(
            shareActivity: shareActivity,
            shareMedia: shareActivity && AppUserSettings.shareMediaWithFriends(userDefaults: userDefaults),
            notesMode: AppUserSettings.shareNotesWithFriends(userDefaults: userDefaults) ? .privateNotes : .off
        )
    }

    // MARK: - Dive

    @MainActor
    static func usesPerActivitySettings(on dive: DiveActivity) -> Bool {
        dive.friendShareBuddySettingsConfigured
    }

    @MainActor
    static func shareActivityEnabled(
        on dive: DiveActivity,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        if usesPerActivitySettings(on: dive) || dive.friendShareBuddyDefaultsCaptured {
            return dive.friendShareActivityEnabled
        }
        return globalDefaults(userDefaults: userDefaults).shareActivity
    }

    @MainActor
    static func shareMediaEnabled(
        on dive: DiveActivity,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        guard shareActivityEnabled(on: dive, userDefaults: userDefaults) else { return false }
        if usesPerActivitySettings(on: dive) || dive.friendShareBuddyDefaultsCaptured {
            return dive.friendShareMediaEnabled
        }
        return globalDefaults(userDefaults: userDefaults).shareMedia
    }

    @MainActor
    static func notesMode(on dive: DiveActivity, userDefaults: UserDefaults = .standard) -> ActivityFriendShareNotesMode {
        if usesPerActivitySettings(on: dive) || dive.friendShareBuddyDefaultsCaptured {
            return ActivityFriendShareNotesMode(rawValue: dive.friendShareNotesModeRaw) ?? .off
        }
        return globalDefaults(userDefaults: userDefaults).notesMode
    }

    @MainActor
    static func selectedMediaIDs(on dive: DiveActivity) -> Set<UUID> {
        if usesPerActivitySettings(on: dive) {
            return decodeMediaIDs(from: dive.friendShareMediaSelectedIDsJSON)
        }
        return []
    }

    /// IDs shown as selected in the per-activity media grid (inherits all gallery items before first save).
    @MainActor
    static func displaySelectedMediaIDs(on dive: DiveActivity, galleryIDs: [UUID]) -> Set<UUID> {
        if usesPerActivitySettings(on: dive) {
            return decodeMediaIDs(from: dive.friendShareMediaSelectedIDsJSON)
        }
        return Set(galleryIDs)
    }

    @MainActor
    static func restrictsMediaToExplicitSelection(on dive: DiveActivity) -> Bool {
        usesPerActivitySettings(on: dive) && dive.friendShareMediaEnabled
    }

    @MainActor
    static func shareOptions(
        for dive: DiveActivity,
        userDefaults: UserDefaults = .standard
    ) -> GoDiveSharedDiveProjectionMapping.ShareOptions {
        shareOptions(
            activityEnabled: shareActivityEnabled(on: dive, userDefaults: userDefaults),
            mediaEnabled: shareMediaEnabled(on: dive, userDefaults: userDefaults),
            notesMode: notesMode(on: dive, userDefaults: userDefaults),
            privateNotes: dive.notes,
            publicNotes: dive.friendSharePublicNotes,
            selectedMediaIDs: selectedMediaIDs(on: dive),
            restrictsMediaToExplicitSelection: restrictsMediaToExplicitSelection(on: dive)
        )
    }

    @MainActor
    static func shouldPublish(
        dive: DiveActivity,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        guard AppUserSettings.shareDivesWithFriends(userDefaults: userDefaults) else { return false }
        if usesPerActivitySettings(on: dive) || dive.friendShareBuddyDefaultsCaptured {
            return dive.friendShareActivityEnabled
        }
        return true
    }

    /// Seeds a brand-new activity as a **local-only draft** (Strava-style publish checkpoint): media /
    /// notes defaults snapshot from global Settings, but sharing stays **off** until the owner explicitly
    /// publishes from the detail-page banner or Activity Settings.
    nonisolated static func seedBuddyShareDefaultsOnNewActivity(
        _ dive: DiveActivity,
        userDefaults: UserDefaults = .standard
    ) {
        guard !dive.friendShareBuddySettingsConfigured, !dive.friendShareBuddyDefaultsCaptured else { return }
        captureGlobalBuddyShareDefaults(on: dive, userDefaults: userDefaults)
        dive.friendShareActivityEnabled = false
        dive.friendSharePublishCheckpointPending = true
    }

    /// One-time backfill for activities created before defaults were snapshotted at creation.
    nonisolated static func captureGlobalBuddyShareDefaultsIfNeeded(
        on dive: DiveActivity,
        userDefaults: UserDefaults = .standard
    ) {
        guard !dive.friendShareBuddySettingsConfigured, !dive.friendShareBuddyDefaultsCaptured else { return }
        captureGlobalBuddyShareDefaults(on: dive, userDefaults: userDefaults)
    }

    /// Draft values for the per-activity settings sheet.
    @MainActor
    static func draftFieldsForDisplay(
        on dive: DiveActivity,
        userDefaults: UserDefaults = .standard
    ) -> (shareActivity: Bool, shareMedia: Bool, notesMode: ActivityFriendShareNotesMode) {
        if usesPerActivitySettings(on: dive) {
            return (
                dive.friendShareActivityEnabled,
                dive.friendShareMediaEnabled,
                ActivityFriendShareNotesMode(rawValue: dive.friendShareNotesModeRaw) ?? .off
            )
        }
        if dive.friendShareBuddyDefaultsCaptured {
            return (
                dive.friendShareActivityEnabled,
                dive.friendShareMediaEnabled,
                ActivityFriendShareNotesMode(rawValue: dive.friendShareNotesModeRaw) ?? .off
            )
        }
        return draftFieldsMatchingGlobalDefaults(userDefaults: userDefaults)
    }

    /// Seeds draft / model fields from global Settings (does not mark configured).
    @MainActor
    static func draftFieldsMatchingGlobalDefaults(
        userDefaults: UserDefaults = .standard
    ) -> (shareActivity: Bool, shareMedia: Bool, notesMode: ActivityFriendShareNotesMode) {
        let defaults = globalDefaults(userDefaults: userDefaults)
        return (defaults.shareActivity, defaults.shareMedia, defaults.notesMode)
    }

    /// Persists a per-activity override snapshot onto the activity model.
    /// Saving settings also resolves the publish checkpoint — the owner made an explicit choice.
    @MainActor
    static func applyConfiguredSettings(
        to dive: DiveActivity,
        shareActivityEnabled: Bool,
        shareMediaEnabled: Bool,
        selectedMediaIDs: Set<UUID>,
        notesMode: ActivityFriendShareNotesMode,
        publicNotes: String?
    ) {
        dive.friendShareBuddySettingsConfigured = true
        dive.friendShareBuddyDefaultsCaptured = true
        dive.friendShareActivityEnabled = shareActivityEnabled
        dive.friendShareMediaEnabled = shareMediaEnabled
        dive.friendShareNotesModeRaw = notesMode.rawValue
        dive.friendSharePublicNotes = publicNotes
        dive.friendShareMediaSelectedIDsJSON = encodeMediaIDs(selectedMediaIDs)
        dive.friendSharePublishCheckpointPending = false
    }

    // MARK: - Snorkel

    @MainActor
    static func usesPerActivitySettings(on snorkel: SnorkelActivity) -> Bool {
        snorkel.friendShareBuddySettingsConfigured
    }

    @MainActor
    static func shareActivityEnabled(
        on snorkel: SnorkelActivity,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        if usesPerActivitySettings(on: snorkel) || snorkel.friendShareBuddyDefaultsCaptured {
            return snorkel.friendShareActivityEnabled
        }
        return globalDefaults(userDefaults: userDefaults).shareActivity
    }

    @MainActor
    static func shareMediaEnabled(
        on snorkel: SnorkelActivity,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        guard shareActivityEnabled(on: snorkel, userDefaults: userDefaults) else { return false }
        if usesPerActivitySettings(on: snorkel) || snorkel.friendShareBuddyDefaultsCaptured {
            return snorkel.friendShareMediaEnabled
        }
        return globalDefaults(userDefaults: userDefaults).shareMedia
    }

    @MainActor
    static func notesMode(
        on snorkel: SnorkelActivity,
        userDefaults: UserDefaults = .standard
    ) -> ActivityFriendShareNotesMode {
        if usesPerActivitySettings(on: snorkel) || snorkel.friendShareBuddyDefaultsCaptured {
            return ActivityFriendShareNotesMode(rawValue: snorkel.friendShareNotesModeRaw) ?? .off
        }
        return globalDefaults(userDefaults: userDefaults).notesMode
    }

    @MainActor
    static func selectedMediaIDs(on snorkel: SnorkelActivity) -> Set<UUID> {
        if usesPerActivitySettings(on: snorkel) {
            return decodeMediaIDs(from: snorkel.friendShareMediaSelectedIDsJSON)
        }
        return []
    }

    @MainActor
    static func displaySelectedMediaIDs(on snorkel: SnorkelActivity, galleryIDs: [UUID]) -> Set<UUID> {
        if usesPerActivitySettings(on: snorkel) {
            return decodeMediaIDs(from: snorkel.friendShareMediaSelectedIDsJSON)
        }
        return Set(galleryIDs)
    }

    @MainActor
    static func restrictsMediaToExplicitSelection(on snorkel: SnorkelActivity) -> Bool {
        usesPerActivitySettings(on: snorkel) && snorkel.friendShareMediaEnabled
    }

    @MainActor
    static func shareOptions(
        for snorkel: SnorkelActivity,
        userDefaults: UserDefaults = .standard
    ) -> GoDiveSharedDiveProjectionMapping.ShareOptions {
        shareOptions(
            activityEnabled: shareActivityEnabled(on: snorkel, userDefaults: userDefaults),
            mediaEnabled: shareMediaEnabled(on: snorkel, userDefaults: userDefaults),
            notesMode: notesMode(on: snorkel, userDefaults: userDefaults),
            privateNotes: snorkel.notes,
            publicNotes: snorkel.friendSharePublicNotes,
            selectedMediaIDs: selectedMediaIDs(on: snorkel),
            restrictsMediaToExplicitSelection: restrictsMediaToExplicitSelection(on: snorkel)
        )
    }

    @MainActor
    static func shouldPublish(
        snorkel: SnorkelActivity,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        guard AppUserSettings.shareDivesWithFriends(userDefaults: userDefaults) else { return false }
        if usesPerActivitySettings(on: snorkel) || snorkel.friendShareBuddyDefaultsCaptured {
            return snorkel.friendShareActivityEnabled
        }
        return true
    }

    /// See the dive overload — new snorkels start as local-only drafts pending the publish checkpoint.
    nonisolated static func seedBuddyShareDefaultsOnNewActivity(
        _ snorkel: SnorkelActivity,
        userDefaults: UserDefaults = .standard
    ) {
        guard !snorkel.friendShareBuddySettingsConfigured, !snorkel.friendShareBuddyDefaultsCaptured else { return }
        captureGlobalBuddyShareDefaults(on: snorkel, userDefaults: userDefaults)
        snorkel.friendShareActivityEnabled = false
        snorkel.friendSharePublishCheckpointPending = true
    }

    nonisolated static func captureGlobalBuddyShareDefaultsIfNeeded(
        on snorkel: SnorkelActivity,
        userDefaults: UserDefaults = .standard
    ) {
        guard !snorkel.friendShareBuddySettingsConfigured, !snorkel.friendShareBuddyDefaultsCaptured else { return }
        captureGlobalBuddyShareDefaults(on: snorkel, userDefaults: userDefaults)
    }

    @MainActor
    static func draftFieldsForDisplay(
        on snorkel: SnorkelActivity,
        userDefaults: UserDefaults = .standard
    ) -> (shareActivity: Bool, shareMedia: Bool, notesMode: ActivityFriendShareNotesMode) {
        if usesPerActivitySettings(on: snorkel) {
            return (
                snorkel.friendShareActivityEnabled,
                snorkel.friendShareMediaEnabled,
                ActivityFriendShareNotesMode(rawValue: snorkel.friendShareNotesModeRaw) ?? .off
            )
        }
        if snorkel.friendShareBuddyDefaultsCaptured {
            return (
                snorkel.friendShareActivityEnabled,
                snorkel.friendShareMediaEnabled,
                ActivityFriendShareNotesMode(rawValue: snorkel.friendShareNotesModeRaw) ?? .off
            )
        }
        return draftFieldsMatchingGlobalDefaults(userDefaults: userDefaults)
    }

    @MainActor
    static func applyConfiguredSettings(
        to snorkel: SnorkelActivity,
        shareActivityEnabled: Bool,
        shareMediaEnabled: Bool,
        selectedMediaIDs: Set<UUID>,
        notesMode: ActivityFriendShareNotesMode,
        publicNotes: String?
    ) {
        snorkel.friendShareBuddySettingsConfigured = true
        snorkel.friendShareBuddyDefaultsCaptured = true
        snorkel.friendShareActivityEnabled = shareActivityEnabled
        snorkel.friendShareMediaEnabled = shareMediaEnabled
        snorkel.friendShareNotesModeRaw = notesMode.rawValue
        snorkel.friendSharePublicNotes = publicNotes
        snorkel.friendShareMediaSelectedIDsJSON = encodeMediaIDs(selectedMediaIDs)
        snorkel.friendSharePublishCheckpointPending = false
    }

    // MARK: - Encoding

    nonisolated static func encodeMediaIDs(_ ids: Set<UUID>) -> String? {
        guard !ids.isEmpty else { return nil }
        let strings = ids.map(\.uuidString).sorted()
        guard let data = try? JSONEncoder().encode(strings) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    nonisolated static func decodeMediaIDs(from json: String?) -> Set<UUID> {
        guard let json,
              let data = json.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(strings.compactMap(UUID.init(uuidString:)))
    }

    // MARK: - Private

    nonisolated private static func captureGlobalBuddyShareDefaults(
        on dive: DiveActivity,
        userDefaults: UserDefaults
    ) {
        let defaults = globalDefaults(userDefaults: userDefaults)
        dive.friendShareActivityEnabled = defaults.shareActivity
        dive.friendShareMediaEnabled = defaults.shareMedia
        dive.friendShareNotesModeRaw = defaults.notesMode.rawValue
        dive.friendShareBuddyDefaultsCaptured = true
    }

    nonisolated private static func captureGlobalBuddyShareDefaults(
        on snorkel: SnorkelActivity,
        userDefaults: UserDefaults
    ) {
        let defaults = globalDefaults(userDefaults: userDefaults)
        snorkel.friendShareActivityEnabled = defaults.shareActivity
        snorkel.friendShareMediaEnabled = defaults.shareMedia
        snorkel.friendShareNotesModeRaw = defaults.notesMode.rawValue
        snorkel.friendShareBuddyDefaultsCaptured = true
    }

    nonisolated private static func shareOptions(
        activityEnabled: Bool,
        mediaEnabled: Bool,
        notesMode: ActivityFriendShareNotesMode,
        privateNotes: String?,
        publicNotes: String?,
        selectedMediaIDs: Set<UUID>,
        restrictsMediaToExplicitSelection: Bool
    ) -> GoDiveSharedDiveProjectionMapping.ShareOptions {
        let notesText: String?
        let includeNotes: Bool
        switch notesMode {
        case .off:
            includeNotes = false
            notesText = nil
        case .privateNotes:
            includeNotes = true
            notesText = privateNotes
        case .publicNotes:
            includeNotes = true
            notesText = publicNotes
        }

        return GoDiveSharedDiveProjectionMapping.ShareOptions(
            includeNotes: activityEnabled && includeNotes,
            notesText: notesText,
            includeMedia: activityEnabled && mediaEnabled,
            selectedMediaIDs: selectedMediaIDs,
            restrictsMediaToExplicitSelection: restrictsMediaToExplicitSelection
        )
    }
}
