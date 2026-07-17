import Foundation
import SwiftData

/// Synced per-account preferences (CloudKit private user store).
///
/// **`UserDefaults`** remains a fast local cache for `@AppStorage` and nonisolated reads.
/// **`shareCrashReports`** stays device-local and is not stored here.
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
        self.updatedAt = updatedAt
    }
}
