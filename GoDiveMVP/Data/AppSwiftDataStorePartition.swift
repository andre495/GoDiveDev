import Foundation
import SwiftData

/// Phase 1 store ownership map for Option A hybrid sync.
///
/// Production opens **split on-disk stores** via **`AppSwiftDataDualStoreBootstrap`**.
/// In-memory tests still use a unified container.
/// These lists define which types live in user / user-local / catalog / diagnostics configurations.
enum AppSwiftDataStorePartition: Sendable {

    /// User-owned structured data mirrored via CloudKit private (dive headers, buddies, media pointers, etc.).
    nonisolated static let userModelTypes: [any PersistentModel.Type] = [
        UserProfile.self,
        DiveActivity.self,
        DiveActivityEquipmentList.self,
        DiveEquipmentEntry.self,
        DiveBuddy.self,
        DiveBuddyTag.self,
        ActivityTag.self,
        DiveMediaPhoto.self,
        DiveMediaBuddyTag.self,
        MarineLifeUserRecord.self,
        SightingInstance.self,
        EquipmentItem.self,
        Certification.self,
        DiveTrip.self,
        DiveTripActivityLink.self,
        DiveTripBuddyLink.self,
        UserMarineLife.self,
        UserDiveSite.self,
        UserPreferences.self,
        SecurityEventRecord.self,
    ]

    /// High-volume samples kept **on-device only** (**`GoDiveUserLocal`**, CloudKit **off**).
    /// Linked to dives by **`diveActivityID`** (no cross-store SwiftData relationship).
    nonisolated static let userLocalModelTypes: [any PersistentModel.Type] = [
        DiveProfilePoint.self,
    ]

    /// Pre–policy-v7 **`GoDiveUser`** files that still embed profile points in the user store.
    nonisolated static var legacyCloudKitUserModelTypes: [any PersistentModel.Type] {
        userModelTypes + userLocalModelTypes
    }

    /// Developer-owned catalog cache (bundled seed today; Firebase CDN refresh in Phase 4).
    ///
    /// User-created species/sites live on **`UserMarineLife`** / **`UserDiveSite`** in the user store.
    /// Catalog types must not hold user-owned rows once migration has run.
    nonisolated static let catalogModelTypes: [any PersistentModel.Type] = [
        MarineLife.self,
        DiveSite.self,
    ]

    /// Local diagnostics; opt-in public CloudKit upload stays outside SwiftData mirroring.
    nonisolated static let diagnosticsModelTypes: [any PersistentModel.Type] = [
        CrashReportRecord.self,
    ]

    /// Every production `@Model` type, in a stable order for the unified container.
    nonisolated static var allModelTypes: [any PersistentModel.Type] {
        userModelTypes + userLocalModelTypes + catalogModelTypes + diagnosticsModelTypes
    }

    /// Type names for tests / migration planning (SwiftData metatypes are not `Equatable`).
    nonisolated static var userModelTypeNames: [String] {
        userModelTypes.map { String(describing: $0) }
    }

    nonisolated static var userLocalModelTypeNames: [String] {
        userLocalModelTypes.map { String(describing: $0) }
    }

    nonisolated static var catalogModelTypeNames: [String] {
        catalogModelTypes.map { String(describing: $0) }
    }

    nonisolated static var diagnosticsModelTypeNames: [String] {
        diagnosticsModelTypes.map { String(describing: $0) }
    }

    nonisolated static var allModelTypeNames: [String] {
        allModelTypes.map { String(describing: $0) }
    }

    // MARK: - Preferences decision (Phase 1)

    /// Keys that should migrate into a synced `UserPreferences` row in Phase 2.
    nonisolated static let syncedPreferenceKeys: [String] = [
        AppUserSettings.automaticallyRenumberDivesKey,
        AppUserSettings.useImperialDisplayUnitsKey,
        AppUserSettings.defaultTankSizeKey,
        AppUserSettings.defaultSaltwaterWeightKilogramsKey,
        AppUserSettings.defaultFreshwaterWeightKilogramsKey,
        AppUserSettings.bulkUddfCreateDiveSitesKey,
        AppUserSettings.autoUploadMediaToActivitiesKey,
    ]

    /// Stay device-local (privacy / diagnostics), not mirrored in the user CloudKit store.
    nonisolated static let localOnlyPreferenceKeys: [String] = [
        AppUserSettings.shareCrashReportsKey,
        AppUserSettings.shareSecurityEventsKey,
    ]

    /// Catalog CDN vendor locked for Phase 4 (developer-owned; not user sync).
    nonisolated static let catalogCDNVendor = "Firebase Storage + Hosting (versioned manifests)"
}
