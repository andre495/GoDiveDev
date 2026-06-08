import Foundation
import SwiftData

/// Removes a **`DiveBuddy`** from the roster and untags them on all dives.
enum DiveBuddyDeletion {
    @MainActor
    static func deletePermanently(_ buddy: DiveBuddy, modelContext: ModelContext) throws {
        let participations = Array(buddy.diveParticipations)
        for tag in participations {
            if let dive = tag.dive {
                DiveBuddyActivityAssociation.removeTag(tag, from: dive, modelContext: modelContext)
            } else {
                buddy.diveParticipations.removeAll { $0.id == tag.id }
                modelContext.delete(tag)
            }
        }
        modelContext.delete(buddy)
        try modelContext.save()
    }
}
