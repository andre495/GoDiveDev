import Foundation
import SwiftData

/// One-off dive / snorkel fetches for navigation destinations — avoids root-tab
/// `@Query` arrays just to resolve a pushed activity by id.
enum OwnerDiveActivityLookup: Sendable {

    nonisolated static func dive(
        id: UUID,
        modelContext: ModelContext
    ) -> DiveActivity? {
        var descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    nonisolated static func snorkel(
        id: UUID,
        modelContext: ModelContext
    ) -> SnorkelActivity? {
        var descriptor = FetchDescriptor<SnorkelActivity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
