import SwiftData

/// Shared SwiftData schema for production and tests.
enum AppSwiftDataSchema {
    nonisolated static let modelTypes: [any PersistentModel.Type] = [
        UserProfile.self,
        DiveActivity.self,
        DiveActivityEquipmentList.self,
        DiveEquipmentEntry.self,
        DiveBuddy.self,
        DiveBuddyTag.self,
        ActivityTag.self,
        DiveMediaPhoto.self,
        DiveMediaBuddyTag.self,
        DiveProfilePoint.self,
        DiveSite.self,
        MarineLife.self,
        MarineLifeUserRecord.self,
        SightingInstance.self,
        EquipmentItem.self,
        Certification.self,
        DiveTrip.self,
        DiveTripActivityLink.self,
        DiveTripBuddyLink.self,
        CrashReportRecord.self,
    ]

    /// Builds a **`ModelContainer`**. On-disk stores perform file I/O — use **`AppModelContainer.loadProduction()`**
    /// at launch (background thread) for **`isStoredInMemoryOnly: false`**; in-memory is fine on any thread (tests / previews).
    nonisolated static func makeContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        let schema = Schema(modelTypes)
        // `cloudKitDatabase: .none` is required: the app has an iCloud container entitlement
        // (crash-report upload via `CrashReportCloudUploader`), and the default `.automatic`
        // would try to CloudKit-mirror this store — our schema (non-optional attributes,
        // unique constraints, inverse-less relationships) intentionally does not support that,
        // and the container fails to load at launch.
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
