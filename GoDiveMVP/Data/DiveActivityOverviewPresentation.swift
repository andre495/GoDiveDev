import Foundation

/// Copy and labels for the dive overview embedded panel (map / tank sheet).
enum DiveActivityOverviewPresentation: Sendable {
    /// Primary sheet header — trimmed **`siteName`**, otherwise import-source fallback.
    nonisolated static func siteHeaderTitle(siteName: String?, fallback: String) -> String {
        let trimmed = siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}
