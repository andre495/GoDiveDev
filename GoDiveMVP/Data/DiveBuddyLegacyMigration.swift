import Foundation
import SwiftData

/// One-time migration from name-only **`DiveBuddyTag`** rows to **`DiveBuddy`** + tag links.
enum DiveBuddyLegacyMigration {
    private static let completedKey = "goDiveDiveBuddyPersonMigrationComplete"

    static func migrateIfNeeded(modelContext: ModelContext) throws {
        guard !UserDefaults.standard.bool(forKey: completedKey) else { return }

        let tags = try modelContext.fetch(FetchDescriptor<DiveBuddyTag>())
        var changed = false
        for tag in tags where tag.buddy == nil {
            let legacyName = tag.legacyDisplayName?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let name = legacyName.isEmpty ? "Buddy" : legacyName
            let buddy = DiveBuddy(displayName: name)
            modelContext.insert(buddy)
            tag.buddy = buddy
            tag.buddyID = buddy.id
            tag.legacyDisplayName = nil

            if let dive = tag.dive,
               let ownerID = dive.ownerProfileID,
               let owner = try? fetchProfile(id: ownerID, modelContext: modelContext)
            {
                DiveBuddyOwnership.assignOwner(owner, to: buddy)
            }
            changed = true
        }

        if changed {
            try modelContext.save()
        }
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    private static func fetchProfile(id: UUID, modelContext: ModelContext) throws -> UserProfile? {
        var descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
