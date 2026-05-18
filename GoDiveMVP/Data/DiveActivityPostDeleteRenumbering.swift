import Foundation
import SwiftData

/// Post-delete dive **#** persistence via **`DiveBackgroundRenumberingWorker`** (off the main actor).
enum DiveActivityPostDeleteRenumbering {

    /// Partial renumber on a background **`ModelActor`** context.
    static func renumberAfterDelete(
        container: ModelContainer,
        deletedStartTime: Date,
        deletedId: UUID
    ) async throws {
        let worker = DiveBackgroundRenumberingWorker(modelContainer: container)
        try await worker.renumberDivesNewerThanDeleted(
            deletedStartTime: deletedStartTime,
            deletedId: deletedId
        )
    }
}
