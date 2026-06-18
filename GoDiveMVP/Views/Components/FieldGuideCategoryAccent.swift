import SwiftUI

/// Per-category gradient accents for Field Guide hub and browse surfaces.
enum FieldGuideCategoryAccent {
    static func gradientTop(_ categoryID: String) -> Color {
        switch categoryID {
        case "fish": AppTheme.Colors.accent
        case "corals": Color(red: 0.95, green: 0.45, blue: 0.55)
        case "other_cnidarians": Color(red: 0.55, green: 0.75, blue: 0.98)
        case "sponges": Color(red: 0.72, green: 0.55, blue: 0.88)
        case "mollusks": Color(red: 0.45, green: 0.72, blue: 0.68)
        case "crustaceans": Color(red: 0.92, green: 0.55, blue: 0.28)
        case "echinoderms": Color(red: 0.85, green: 0.38, blue: 0.42)
        case "worms": Color(red: 0.62, green: 0.48, blue: 0.36)
        case "colonial_invertebrates": Color(red: 0.48, green: 0.62, blue: 0.82)
        case "marine_reptiles": Color(red: 0.34, green: 0.68, blue: 0.48)
        case "marine_mammals": Color(red: 0.28, green: 0.52, blue: 0.78)
        default: AppTheme.Colors.accent
        }
    }

    static func gradientBottom(_ categoryID: String) -> Color {
        gradientTop(categoryID).opacity(0.18)
    }
}
