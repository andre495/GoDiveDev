import Foundation

/// Field Guide hub + browse category hues — contrasty in light mode, pastel in dark mode.
enum FieldGuideCategoryAccentPresentation: Sendable {
    typealias RGB = AdaptiveAccentColor.RGB

    struct HuePair: Sendable, Equatable {
        let light: RGB
        let dark: RGB
    }

    /// Hub tile order matches **`FieldGuideTaxonomy.categories`**:
    /// Yellow → Red → Purple → Light Green → Orange → Cyan → Deep Pink.
    nonisolated static func huePair(for categoryID: String) -> HuePair {
        switch categoryID {
        case "plants", "marine_plants":
            return HuePair(
                light: RGB(red: 0.62, green: 0.48, blue: 0.04),
                dark: RGB(red: 0.98, green: 0.82, blue: 0.18)
            )
        case "sponges":
            return HuePair(
                light: RGB(red: 0.72, green: 0.12, blue: 0.14),
                dark: RGB(red: 0.92, green: 0.22, blue: 0.24)
            )
        case "corals":
            return HuePair(
                light: RGB(red: 0.48, green: 0.14, blue: 0.68),
                dark: RGB(red: 0.62, green: 0.28, blue: 0.88)
            )
        case "invertebrates", "mollusks", "crustaceans", "echinoderms", "worms", "colonial_invertebrates", "other_cnidarians":
            return HuePair(
                light: RGB(red: 0.18, green: 0.52, blue: 0.22),
                dark: RGB(red: 0.52, green: 0.88, blue: 0.42)
            )
        case "fishes", "fish":
            return HuePair(
                light: RGB(red: 0.78, green: 0.38, blue: 0.04),
                dark: RGB(red: 1.00, green: 0.55, blue: 0.12)
            )
        case "reptiles", "sea_turtles", "marine_reptiles":
            return HuePair(
                light: RGB(red: 0.04, green: 0.48, blue: 0.52),
                dark: RGB(red: 0.12, green: 0.82, blue: 0.88)
            )
        case "global_search_media":
            return HuePair(
                light: RGB(red: 0.48, green: 0.32, blue: 0.72),
                dark: RGB(red: 0.72, green: 0.58, blue: 0.94)
            )
        case "mammals", "marine_mammals":
            return HuePair(
                light: RGB(red: 0.68, green: 0.06, blue: 0.36),
                dark: RGB(red: 0.92, green: 0.12, blue: 0.52)
            )
        default:
            return huePair(for: "fishes")
        }
    }

    nonisolated static func lightGradientTopRGB(for categoryID: String) -> RGB {
        huePair(for: categoryID).light
    }

    nonisolated static func darkGradientTopRGB(for categoryID: String) -> RGB {
        huePair(for: categoryID).dark
    }
}
