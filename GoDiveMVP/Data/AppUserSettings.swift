import Foundation

/// User-facing preferences. Synced keys live in SwiftData **`UserPreferences`** (CloudKit) with a
/// **`UserDefaults`** cache for `@AppStorage` and nonisolated reads. **`shareCrashReports`** and
/// **`shareSecurityEvents`** are device-local only.
enum AppUserSettings: Sendable {
    /// When **`true`**, import/seed may run **`renumberAllChronologically`**; **delete** uses partial tail renumber on a background context (**`DiveActivityPostDeleteRenumbering`**).
    nonisolated static let automaticallyRenumberDivesKey = "goDiveAutomaticallyRenumberDives"

    /// When **`true`**, **`EnvironmentValues.diveDisplayUnitSystem`** is **`.imperial`** (depth in **ft**, temps in **°F**, cylinder pressure in **psi**, tank volume in **cu ft**). **`false`** → **`.metric`**. Stored **`DiveActivity`** values stay canonical (m, °C, psi).
    nonisolated static let useImperialDisplayUnitsKey = "goDiveUseImperialDisplayUnits"

    /// **`DefaultTankSize.rawValue`** — default rated size + material for new imports (**AL80**, **AL63**, **ST100**, **ST120**).
    nonisolated static let defaultTankSizeKey = "goDiveDefaultTankSize"

    /// Canonical **kg** for **Settings → Default Diver Weights → Salt water**; absent key = no default.
    nonisolated static let defaultSaltwaterWeightKilogramsKey = "goDiveDefaultSaltwaterWeightKilograms"

    /// Canonical **kg** for **Settings → Default Diver Weights → Fresh water**; absent key = no default.
    nonisolated static let defaultFreshwaterWeightKilogramsKey = "goDiveDefaultFreshwaterWeightKilograms"

    /// Bulk **UDDF** import: insert catalog **`DiveSite`** rows for unmatched site names in the file.
    nonisolated static let bulkUddfCreateDiveSitesKey = "goDiveBulkUddfCreateDiveSites"

    /// When **`true`**, attach Photos library items whose capture time falls within each dive window after dive import.
    nonisolated static let autoUploadMediaToActivitiesKey = "goDiveAutoUploadMediaToActivities"

    /// When **`true`**, stored crash reports upload to the developer's CloudKit public database
    /// (**`CrashReportCloudUploader`**). Default **off** — sharing is opt-in.
    nonisolated static let shareCrashReportsKey = "goDiveShareCrashReports"

    /// When **`true`**, scrubbed security events upload to the developer's CloudKit public database
    /// (**`SecurityEventCloudUploader`**). Default **off** — sharing is opt-in. The local journal
    /// still syncs via private CloudKit with the dive account.
    nonisolated static let shareSecurityEventsKey = "goDiveShareSecurityEvents"

    /// When **`true`** and the user has friends, friend-visible dive projections publish to Firestore.
    /// Default **on** (registered); notes/media stay opt-in separately.
    nonisolated static let shareDivesWithFriendsKey = "goDiveShareDivesWithFriends"

    /// When **`true`**, dive notes are included in friend-visible projections. Default **off**.
    nonisolated static let shareNotesWithFriendsKey = "goDiveShareNotesWithFriends"

    /// When **`true`**, dive media previews upload for friends. Default **off**.
    nonisolated static let shareMediaWithFriendsKey = "goDiveShareMediaWithFriends"

    /// When **`true`**, full-quality shared media uploads wait for Wi‑Fi (thumbnails may still upload on cellular).
    nonisolated static let shareMediaOnWiFiOnlyKey = "goDiveShareMediaOnWiFiOnly"

    /// Legacy key — downloads always use Wi‑Fi or cellular; see **`downloadFriendMediaOnWiFiOnly`**.
    nonisolated static let downloadFriendMediaOnWiFiOnlyKey = "goDiveDownloadFriendMediaOnWiFiOnly"

    /// Master switch for all GoDive notifications (buddy / gear / trip). Default **on**.
    nonisolated static let notifyAllNotificationsKey = "goDiveNotifyAllNotifications"

    /// When **`true`**, this user receives push notifications when friends share new activities.
    /// Default **on**; mirrored to Firestore **`users/{uid}/private/notificationPrefs`** so the
    /// Cloud Function can filter recipients server-side. Gated by **`notifyAllNotifications`**.
    nonisolated static let notifyBuddyActivitySharesKey = "goDiveNotifyBuddyActivityShares"

    /// Global default for new gear service reminders (per-item settings still override). Default **on**.
    /// Gated by **`notifyAllNotifications`**.
    nonisolated static let notifyGearServiceRemindersKey = "goDiveNotifyGearServiceReminders"

    /// Master switch for upcoming-trip local reminders. Default **on**.
    /// Gated by **`notifyAllNotifications`**.
    nonisolated static let notifyTripRemindersKey = "goDiveNotifyTripReminders"

    nonisolated static var automaticallyRenumberDives: Bool {
        UserDefaults.standard.bool(forKey: automaticallyRenumberDivesKey)
    }

    static var useImperialDisplayUnits: Bool {
        UserDefaults.standard.bool(forKey: useImperialDisplayUnitsKey)
    }

    nonisolated static func diveDisplayUnitSystem(userDefaults: UserDefaults = .standard) -> DiveDisplayUnitSystem {
        userDefaults.bool(forKey: useImperialDisplayUnitsKey) ? .imperial : .metric
    }

    static var defaultTankSize: DefaultTankSize {
        let raw = UserDefaults.standard.string(forKey: defaultTankSizeKey)
        return raw.flatMap(DefaultTankSize.init(rawValue:)) ?? DiveActivityTankDefaults.defaultSize
    }

    nonisolated static func defaultSaltwaterWeightKilograms(userDefaults: UserDefaults = .standard) -> Double? {
        optionalPositiveWeightKilograms(forKey: defaultSaltwaterWeightKilogramsKey, userDefaults: userDefaults)
    }

    nonisolated static func defaultFreshwaterWeightKilograms(userDefaults: UserDefaults = .standard) -> Double? {
        optionalPositiveWeightKilograms(forKey: defaultFreshwaterWeightKilogramsKey, userDefaults: userDefaults)
    }

    nonisolated static func setDefaultSaltwaterWeightKilograms(_ kilograms: Double?, userDefaults: UserDefaults = .standard) {
        setOptionalPositiveWeightKilograms(kilograms, forKey: defaultSaltwaterWeightKilogramsKey, userDefaults: userDefaults)
    }

    nonisolated static func setDefaultFreshwaterWeightKilograms(_ kilograms: Double?, userDefaults: UserDefaults = .standard) {
        setOptionalPositiveWeightKilograms(kilograms, forKey: defaultFreshwaterWeightKilogramsKey, userDefaults: userDefaults)
    }

    static var autoUploadMediaToActivities: Bool {
        UserDefaults.standard.bool(forKey: autoUploadMediaToActivitiesKey)
    }

    /// `nonisolated` — read from crash-upload paths off the main actor. Unregistered key
    /// defaults to `false`, keeping crash sharing opt-in.
    nonisolated static func shareCrashReports(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.bool(forKey: shareCrashReportsKey)
    }

    nonisolated static func shareSecurityEvents(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.bool(forKey: shareSecurityEventsKey)
    }

    nonisolated static func shareDivesWithFriends(userDefaults: UserDefaults = .standard) -> Bool {
        if userDefaults.object(forKey: shareDivesWithFriendsKey) == nil {
            return true
        }
        return userDefaults.bool(forKey: shareDivesWithFriendsKey)
    }

    nonisolated static func shareNotesWithFriends(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.bool(forKey: shareNotesWithFriendsKey)
    }

    nonisolated static func shareMediaWithFriends(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.bool(forKey: shareMediaWithFriendsKey)
    }

    nonisolated static func shareMediaOnWiFiOnly(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.bool(forKey: shareMediaOnWiFiOnlyKey)
    }

    /// Always **`false`** — buddy media downloads use Wi‑Fi or cellular (no Settings gate).
    nonisolated static func downloadFriendMediaOnWiFiOnly(userDefaults: UserDefaults = .standard) -> Bool {
        _ = userDefaults
        return false
    }

    nonisolated static func notifyAllNotifications(userDefaults: UserDefaults = .standard) -> Bool {
        registeredOrDefaultTrue(forKey: notifyAllNotificationsKey, userDefaults: userDefaults)
    }

    /// Stored buddy-activity preference (ignores the all-notifications master). Used by Settings sync UI.
    nonisolated static func notifyBuddyActivitySharesPreference(userDefaults: UserDefaults = .standard) -> Bool {
        registeredOrDefaultTrue(forKey: notifyBuddyActivitySharesKey, userDefaults: userDefaults)
    }

    /// Effective: master on **and** buddy-activity preference on.
    nonisolated static func notifyBuddyActivityShares(userDefaults: UserDefaults = .standard) -> Bool {
        notifyAllNotifications(userDefaults: userDefaults)
            && notifyBuddyActivitySharesPreference(userDefaults: userDefaults)
    }

    /// Stored gear-reminder default (ignores the all-notifications master). Used by Settings sync UI.
    nonisolated static func notifyGearServiceRemindersPreference(userDefaults: UserDefaults = .standard) -> Bool {
        registeredOrDefaultTrue(forKey: notifyGearServiceRemindersKey, userDefaults: userDefaults)
    }

    /// Effective: master on **and** gear-reminder preference on.
    nonisolated static func notifyGearServiceReminders(userDefaults: UserDefaults = .standard) -> Bool {
        notifyAllNotifications(userDefaults: userDefaults)
            && notifyGearServiceRemindersPreference(userDefaults: userDefaults)
    }

    /// Stored trip-reminder preference (ignores the all-notifications master). Used by Settings sync UI.
    nonisolated static func notifyTripRemindersPreference(userDefaults: UserDefaults = .standard) -> Bool {
        registeredOrDefaultTrue(forKey: notifyTripRemindersKey, userDefaults: userDefaults)
    }

    /// Effective: master on **and** trip-reminder preference on.
    nonisolated static func notifyTripReminders(userDefaults: UserDefaults = .standard) -> Bool {
        notifyAllNotifications(userDefaults: userDefaults)
            && notifyTripRemindersPreference(userDefaults: userDefaults)
    }

    /// Toggle defaults applied when the user has never changed them (call once at launch).
    /// **`register(defaults:)`** only fills keys that are not already set, so it never overrides a saved choice.
    nonisolated static func registerDefaultValues(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            automaticallyRenumberDivesKey: true,
            useImperialDisplayUnitsKey: true,
            autoUploadMediaToActivitiesKey: true,
            shareDivesWithFriendsKey: true,
            shareNotesWithFriendsKey: false,
            shareMediaWithFriendsKey: false,
            shareMediaOnWiFiOnlyKey: false,
            notifyAllNotificationsKey: true,
            notifyBuddyActivitySharesKey: true,
            notifyGearServiceRemindersKey: true,
            notifyTripRemindersKey: true,
        ])
    }

    private nonisolated static func registeredOrDefaultTrue(
        forKey key: String,
        userDefaults: UserDefaults
    ) -> Bool {
        if userDefaults.object(forKey: key) == nil {
            return true
        }
        return userDefaults.bool(forKey: key)
    }

    private nonisolated static func optionalPositiveWeightKilograms(
        forKey key: String,
        userDefaults: UserDefaults
    ) -> Double? {
        guard userDefaults.object(forKey: key) != nil else { return nil }
        let value = userDefaults.double(forKey: key)
        return value > 0 ? value : nil
    }

    private nonisolated static func setOptionalPositiveWeightKilograms(
        _ kilograms: Double?,
        forKey key: String,
        userDefaults: UserDefaults
    ) {
        guard let kilograms, kilograms > 0 else {
            userDefaults.removeObject(forKey: key)
            return
        }
        userDefaults.set(kilograms, forKey: key)
    }
}
