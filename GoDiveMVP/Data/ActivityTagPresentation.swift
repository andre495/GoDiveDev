import Foundation

/// Display helpers for activity-tag oval chips (map overview, logbook search, tags sheet).
enum ActivityTagPresentation: Sendable {
    /// Max visible characters on oval dive-tag chips before an ellipsis suffix.
    nonisolated static let chipTitleMaxLength = 25

    nonisolated static func chipDisplayTitle(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > chipTitleMaxLength else { return trimmed }
        return String(trimmed.prefix(chipTitleMaxLength)) + "…"
    }
}
