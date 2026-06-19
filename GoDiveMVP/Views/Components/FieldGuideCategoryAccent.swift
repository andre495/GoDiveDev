import SwiftUI

/// Per-category gradient accents for Field Guide hub and browse surfaces.
enum FieldGuideCategoryAccent {
    static func gradientTop(_ categoryID: String) -> Color {
        switch categoryID {
        case "fishes", "fish": AppTheme.Colors.accent
        case "plants", "marine_plants": Color(red: 0.38, green: 0.72, blue: 0.42)
        case "corals": Color(red: 0.95, green: 0.45, blue: 0.55)
        case "invertebrates", "mollusks", "crustaceans", "echinoderms", "worms", "colonial_invertebrates", "other_cnidarians":
            Color(red: 0.55, green: 0.75, blue: 0.98)
        case "sponges": Color(red: 0.72, green: 0.55, blue: 0.88)
        case "reptiles", "sea_turtles", "marine_reptiles": Color(red: 0.34, green: 0.68, blue: 0.48)
        case "mammals", "marine_mammals": Color(red: 0.28, green: 0.52, blue: 0.78)
        default: AppTheme.Colors.accent
        }
    }

    static func gradientBottom(_ categoryID: String) -> Color {
        gradientTop(categoryID).opacity(0.18)
    }
}
