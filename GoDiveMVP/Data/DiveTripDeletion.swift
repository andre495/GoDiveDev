import Foundation
import SwiftData

/// Removes a **`DiveTrip`** and its dive link rows from the store.
enum DiveTripDeletion {

    @MainActor
    static func deletePermanently(_ trip: DiveTrip, modelContext: ModelContext) throws {
        modelContext.delete(trip)
        try modelContext.save()
        DiveTripLogbookSync.notifyGroupingDidChange()
    }
}
