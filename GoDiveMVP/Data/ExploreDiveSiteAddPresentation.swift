import Foundation

/// Copy and chrome for manually adding a catalog dive site from **Explore**.
enum ExploreDiveSiteAddPresentation: Sendable {
    nonisolated static let sheetTitle = "New dive site"
    nonisolated static let chromeAccessibilityLabel = "Add dive site"
    nonisolated static let chromeSystemImage = "plus"
    nonisolated static let chromeAccessibilityIdentifier = "Explore.AddDiveSite"
    nonisolated static let cancelAccessibilityIdentifier = "Explore.AddDiveSiteSheet.Cancel"
    nonisolated static let doneAccessibilityIdentifier = "Explore.AddDiveSiteSheet.Done"
}
