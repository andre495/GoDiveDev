import SwiftData

/// Shared SwiftData schema for production and tests.
enum AppSwiftDataSchema {
    static let modelTypes: [any PersistentModel.Type] = [
        UserProfile.self,
        DiveActivity.self,
        DiveBuddyTag.self,
        DiveProfilePoint.self,
        DiveSite.self,
        EquipmentItem.self,
        Certification.self,
    ]

    static func makeContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        let schema = Schema(modelTypes)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
