import Foundation

/// Generic Release-safe copy for failures that must not echo OS / SDK error strings (OWASP Phase 5).
enum GoDiveUserFacingError: Sendable {

    nonisolated static let signInFailed = AccountSession.signInFailureUserMessage

    nonisolated static let accountDeletionFailed =
        "Account deletion could not be completed. Please try again."

    nonisolated static let importFailed =
        "This file could not be imported. Try another export or a smaller file."

    /// Prefer known safe import copy; fall back to **`importFailed`** for unexpected errors.
    nonisolated static func importUserMessage(for error: Error) -> String {
        if let limits = error as? DiveFileImportLimits.Error {
            return limits.errorDescription ?? importFailed
        }
        if error is CancellationError {
            return "Import cancelled."
        }
        if let fit = error as? FitDecodeError, let message = fit.errorDescription, !message.isEmpty {
            return message
        }
        if let fit = error as? FitSnorkelDecodeError, let message = fit.errorDescription, !message.isEmpty {
            return message
        }
        if let uddf = error as? UddfDecodeError, let message = uddf.errorDescription, !message.isEmpty {
            return message
        }
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           description == "Could not access the selected file."
        {
            return description
        }
        return importFailed
    }

    /// Records an **`import.reject`** security event with a coarse detail token.
    nonisolated static func recordImportRejection(_ error: Error) {
        if let limits = error as? DiveFileImportLimits.Error {
            GoDiveSecurityEvent.record(.importRejected, detail: limits.securityEventDetail)
            return
        }
        if error is CancellationError {
            return
        }
        if error is FitDecodeError {
            GoDiveSecurityEvent.record(.importRejected, detail: "fit.decode")
            return
        }
        if error is FitSnorkelDecodeError {
            GoDiveSecurityEvent.record(.importRejected, detail: "fit.snorkel.decode")
            return
        }
        if error is UddfDecodeError {
            GoDiveSecurityEvent.record(.importRejected, detail: "uddf.decode")
            return
        }
        GoDiveSecurityEvent.record(.importRejected, detail: "decodeOrPersist")
    }
}
