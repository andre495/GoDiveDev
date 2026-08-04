import Foundation
import SwiftData

/// Deletes one **`SnorkelActivity`** and its related rows on a background **`ModelContext`** (**`@ModelActor`**).
@ModelActor
actor SnorkelBackgroundDeletionWorker {

    enum DeletionError: Error, Equatable {
        case snorkelNotFound(UUID)
    }

    func deleteSnorkel(id: UUID) throws {
        guard try SnorkelActivityPersistenceDeletion.deleteSnorkelAndRelatedRecords(
            snorkelID: id,
            modelContext: modelContext
        ) != nil else {
            throw DeletionError.snorkelNotFound(id)
        }
    }
}
