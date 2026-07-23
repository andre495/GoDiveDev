import SwiftUI

/// Per-category gradient accents for Field Guide hub and browse surfaces.
enum FieldGuideCategoryAccent {
    static func gradientTop(_ categoryID: String) -> Color {
        let pair = FieldGuideCategoryAccentPresentation.huePair(for: categoryID)
        return AdaptiveAccentColor.color(light: pair.light, dark: pair.dark)
    }

    static func gradientBottom(_ categoryID: String) -> Color {
        gradientTop(categoryID).opacity(0.18)
    }
}
