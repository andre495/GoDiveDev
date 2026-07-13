import SwiftUI

/// Per-category gradient accents for Field Guide hub and browse surfaces.
///
/// Hub tile order matches **`FieldGuideTaxonomy.categories`**:
/// Yellow → Red → Purple → Light Green → Orange → Cyan → Deep Pink.
enum FieldGuideCategoryAccent {
    static func gradientTop(_ categoryID: String) -> Color {
        switch categoryID {
        case "plants", "marine_plants":
            // Yellow
            Color(red: 0.98, green: 0.82, blue: 0.18)
        case "sponges":
            // Red
            Color(red: 0.92, green: 0.22, blue: 0.24)
        case "corals":
            // Purple
            Color(red: 0.62, green: 0.28, blue: 0.88)
        case "invertebrates", "mollusks", "crustaceans", "echinoderms", "worms", "colonial_invertebrates", "other_cnidarians":
            // Light Green
            Color(red: 0.52, green: 0.88, blue: 0.42)
        case "fishes", "fish":
            // Orange
            Color(red: 1.00, green: 0.55, blue: 0.12)
        case "reptiles", "sea_turtles", "marine_reptiles":
            // Cyan
            Color(red: 0.12, green: 0.82, blue: 0.88)
        case "global_search_media":
            // Lavender purple — Search → Media tile
            Color(red: 0.72, green: 0.58, blue: 0.94)
        case "mammals", "marine_mammals":
            // Deep Pink
            Color(red: 0.92, green: 0.12, blue: 0.52)
        default:
            Color(red: 1.00, green: 0.55, blue: 0.12)
        }
    }

    static func gradientBottom(_ categoryID: String) -> Color {
        gradientTop(categoryID).opacity(0.18)
    }
}
