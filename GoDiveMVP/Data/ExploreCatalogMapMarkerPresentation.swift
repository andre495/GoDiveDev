import CoreGraphics
import Foundation

/// Shared Explore map pin label rules (MapKit + Google Maps experiment).
enum ExploreCatalogMapMarkerPresentation: Sendable {
    nonisolated static let titleMaxCharacters = 28
    nonisolated static let labelFontSize: CGFloat = 11
    nonisolated static let labelHorizontalPadding: CGFloat = 6
    nonisolated static let labelVerticalPadding: CGFloat = 3
    nonisolated static let pinToLabelSpacing: CGFloat = 2
    nonisolated static let labelMaxWidth: CGFloat = 132

    /// Truncates long catalog site names for on-map pin labels.
    nonisolated static func displayTitle(for siteName: String) -> String {
        let trimmed = siteName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > titleMaxCharacters else { return trimmed }
        return String(trimmed.prefix(titleMaxCharacters - 1)) + "…"
    }
}
