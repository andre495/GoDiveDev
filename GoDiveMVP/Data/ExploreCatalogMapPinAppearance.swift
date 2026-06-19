import Foundation
#if canImport(UIKit)
import UIKit

/// Explore map pin color — visited logbook sites vs unvisited reference sites.
enum ExploreCatalogMapPinAppearance: Sendable {
    nonisolated static func pinTintColor(isVisited: Bool) -> UIColor {
        isVisited ? .systemRed : .systemBlue
    }

    nonisolated static func accessibilityLabel(siteName: String, isVisited: Bool) -> String {
        isVisited ? "Visited dive site \(siteName)" : "Dive site \(siteName)"
    }
}
#endif
