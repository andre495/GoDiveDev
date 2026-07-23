import Foundation

/// User-facing alert copy after snorkel FIT import finishes.
enum SnorkelImportAlertPresentation: Sendable {

    struct Payload: Equatable, Sendable {
        let isSuccess: Bool
        let importedCount: Int
        let detailMessage: String
    }

    nonisolated static func title(for payload: Payload) -> String {
        payload.isSuccess ? "Import complete" : "Import failed"
    }

    nonisolated static func message(for payload: Payload) -> String {
        let count = max(0, payload.importedCount)
        let countLine = "\(count) activit\(count == 1 ? "y" : "ies") imported"
        let trimmedDetail = payload.detailMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDetail.isEmpty else { return countLine }
        if payload.isSuccess, trimmedDetail.hasPrefix(FitSnorkelFileImport.importSuccessMessagePrefix) {
            return "\(countLine)\n\n\(trimmedDetail)"
        }
        if payload.isSuccess {
            return countLine
        }
        return "\(countLine)\n\n\(trimmedDetail)"
    }

    nonisolated static func payload(for outcome: SnorkelFileImportOutcome) -> Payload {
        Payload(
            isSuccess: outcome.didSucceed,
            importedCount: outcome.importedActivityCount,
            detailMessage: outcome.userMessage
        )
    }

    nonisolated static func failurePayload(message: String) -> Payload {
        Payload(isSuccess: false, importedCount: 0, detailMessage: message)
    }
}
