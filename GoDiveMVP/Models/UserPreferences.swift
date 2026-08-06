import Foundation
import SwiftData

/// Synced per-account preferences (CloudKit private user store).
///
/// **`UserDefaults`** remains a fast local cache for `@AppStorage` and nonisolated reads.
/// **`shareCrashReports`** and **`shareSecurityEvents`** stay device-local and are not stored here.
@Model
final class UserPreferences {

    var id: UUID = UUID()

    var ownerProfileID: UUID?
    @Relationship
    var owner: UserProfile?

    var automaticallyRenumberDives: Bool = true
    var useImperialDisplayUnits: Bool = true
    /// **`DefaultTankSize.rawValue`**.
    var defaultTankSizeRaw: String = DefaultTankSize.al80.rawValue
    var defaultSaltwaterWeightKilograms: Double?
    var defaultFreshwaterWeightKilograms: Double?
    var bulkUddfCreateDiveSites: Bool = true
    var autoUploadMediaToActivities: Bool = true
    /// Anonymized community marine-life sighting contributions (Firebase ontology graph). Default **on**.
    var contributeCommunitySightings: Bool = true
    /// Master switch for all notification categories (buddy / gear / trip).
    var notifyAllNotifications: Bool = true
    /// Global default for new gear service reminder selections (per-item overrides).
    var notifyGearServiceReminders: Bool = true
    /// Preference for upcoming-trip local reminders (also gated by **`notifyAllNotifications`**).
    var notifyTripReminders: Bool = true

    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        owner: UserProfile? = nil,
        automaticallyRenumberDives: Bool = true,
        useImperialDisplayUnits: Bool = true,
        defaultTankSizeRaw: String = DefaultTankSize.al80.rawValue,
        defaultSaltwaterWeightKilograms: Double? = nil,
        defaultFreshwaterWeightKilograms: Double? = nil,
        bulkUddfCreateDiveSites: Bool = true,
        autoUploadMediaToActivities: Bool = true,
        contributeCommunitySightings: Bool = true,
        notifyAllNotifications: Bool = true,
        notifyGearServiceReminders: Bool = true,
        notifyTripReminders: Bool = true,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.owner = owner
        self.ownerProfileID = owner?.id
        self.automaticallyRenumberDives = automaticallyRenumberDives
        self.useImperialDisplayUnits = useImperialDisplayUnits
        self.defaultTankSizeRaw = defaultTankSizeRaw
        self.defaultSaltwaterWeightKilograms = defaultSaltwaterWeightKilograms
        self.defaultFreshwaterWeightKilograms = defaultFreshwaterWeightKilograms
        self.bulkUddfCreateDiveSites = bulkUddfCreateDiveSites
        self.autoUploadMediaToActivities = autoUploadMediaToActivities
        self.contributeCommunitySightings = contributeCommunitySightings
        self.notifyAllNotifications = notifyAllNotifications
        self.notifyGearServiceReminders = notifyGearServiceReminders
        self.notifyTripReminders = notifyTripReminders
        self.updatedAt = updatedAt
    }
}
