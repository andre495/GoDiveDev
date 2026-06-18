import Foundation

/// Read-only labels for catalog **`DiveSite`** UI.
enum DiveSitePresentation: Sendable {
    nonisolated static func waterTypeLabel(for site: DiveSite) -> String {
        site.resolvedWaterType.displayTitle
    }
}
