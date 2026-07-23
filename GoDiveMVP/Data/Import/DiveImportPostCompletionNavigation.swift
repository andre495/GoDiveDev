import Foundation

/// Which imported activity to open after file import completes (Logbook navigation).
enum DiveImportPostCompletionNavigation: Sendable {

    /// **`primaryInsertedID`** is the newest inserted dive (**`UddfDiveFileImport.primaryInsertedActivity`**).
    nonisolated static func importedDetailTargetID(
        importedCount: Int,
        primaryInsertedID: UUID?
    ) -> UUID? {
        guard importedCount > 0, let primaryInsertedID else { return nil }
        return primaryInsertedID
    }
}
