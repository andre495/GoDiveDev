import Foundation

/// Result of **`FitDiveFileImport`** / **`UddfDiveFileImport`** save attempts (user-facing message + optional primary dive for navigation).
struct DiveFileImportOutcome: Equatable {
    let userMessage: String
    let primaryInsertedDiveId: UUID?
    /// New rows saved (multi-dive UDDF).
    let insertedCount: Int?
    /// Rows skipped as duplicates of the logbook (**`DiveActivityDuplicateMatcher`**).
    let skippedDuplicateCount: Int?
    /// Dives parsed from the file before duplicate filtering.
    let totalInFile: Int?
    /// New **`DiveSite`** rows created during import site linking (not links to existing catalog sites).
    let createdDiveSiteCount: Int?

    init(
        userMessage: String,
        primaryInsertedDiveId: UUID?,
        insertedCount: Int? = nil,
        skippedDuplicateCount: Int? = nil,
        totalInFile: Int? = nil,
        createdDiveSiteCount: Int? = nil
    ) {
        self.userMessage = userMessage
        self.primaryInsertedDiveId = primaryInsertedDiveId
        self.insertedCount = insertedCount
        self.skippedDuplicateCount = skippedDuplicateCount
        self.totalInFile = totalInFile
        self.createdDiveSiteCount = createdDiveSiteCount
    }

    /// Bulk UDDF finished parsing + persist (success or all-duplicate); use for the completion summary alert.
    var bulkImportFinishedWithCounts: Bool {
        totalInFile != nil
    }

    var didSucceed: Bool {
        DiveFileImportSuccess.matches(userMessage)
    }
}

/// Detects successful **Add activity** import return strings (**.fit** and **.uddf**).
enum DiveFileImportSuccess {
    static func matches(_ message: String) -> Bool {
        if message.hasPrefix(FitDiveFileImport.importSuccessMessagePrefix) {
            return true
        }
        if message.hasPrefix("Imported "), message.contains("dives") {
            return true
        }
        return false
    }
}
