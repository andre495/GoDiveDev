import SwiftData

/// Shared SwiftData schema for production and tests.
enum AppSwiftDataSchema {
    nonisolated static let modelTypes: [any PersistentModel.Type] = [
        UserProfile.self,
        DiveActivity.self,
        DiveActivityEquipmentList.self,
        DiveEquipmentEntry.self,
        DiveBuddyTag.self,
        ActivityTag.self,
        DiveMediaPhoto.self,
        DiveProfilePoint.self,
        DiveSite.self,
        MarineLife.self,
        MarineLifeUserRecord.self,
        SightingInstance.self,
        EquipmentItem.self,
        Certification.self,
    ]

    /// Builds a **`ModelContainer`**. On-disk stores perform file I/O — use **`AppModelContainer.loadProduction()`**
    /// at launch (background thread) for **`isStoredInMemoryOnly: false`**; in-memory is fine on any thread (tests / previews).
    nonisolated static func makeContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        let schema = Schema(modelTypes)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
