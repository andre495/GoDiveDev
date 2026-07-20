import Foundation

/// Trip share PNG paths stay under the system temp directory (OWASP Phase 4).
enum TripShareTempFilePolicy: Sendable {

    /// `true` when `url` resolves under `FileManager.default.temporaryDirectory`.
    nonisolated static func isUnderTemporaryDirectory(_ url: URL) -> Bool {
        let temp = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().standardizedFileURL
        let candidate = url.resolvingSymlinksInPath().standardizedFileURL
        return candidate.path.hasPrefix(temp.path)
    }

    /// Share sheets should present the image item — not a raw absolute path string in UI chrome.
    nonisolated static func shareItemIsFileURLNotPathString(_ url: URL) -> Bool {
        url.isFileURL && isUnderTemporaryDirectory(url)
    }
}
