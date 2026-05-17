import Foundation

/// Result of **`FitDiveFileImport`** / **`UddfDiveFileImport`** save attempts (user-facing message + optional primary dive for navigation).
struct DiveFileImportOutcome: Equatable {
    let userMessage: String
    let primaryInsertedDiveId: UUID?

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
        if let regex = try? Regex(#"^Imported [0-9]+ dives\.$"#), message.wholeMatch(of: regex) != nil {
            return true
        }
        return false
    }
}
