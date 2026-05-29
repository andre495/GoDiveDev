import Foundation
import SwiftData

/// Deletes one **`DiveActivity`** and its related rows on a background **`ModelContext`** (**`@ModelActor`**).
@ModelActor
actor DiveBackgroundDeletionWorker {

    enum DeletionError: Error, Equatable {
        case diveNotFound(UUID)
    }

    func deleteDive(id: UUID) throws {
        guard try DiveActivityPersistenceDeletion.deleteDiveAndRelatedRecords(
            diveID: id,
            modelContext: modelContext
        ) != nil else {
            throw DeletionError.diveNotFound(id)
        }
    }
}
