import SwiftUI

/// Per-category gradient accents for Field Guide hub and browse surfaces.
enum FieldGuideCategoryAccent {
    static func gradientTop(_ categoryID: String) -> Color {
        let pair = FieldGuideCategoryAccentPresentation.huePair(for: categoryID)
        return AdaptiveAccentColor.color(light: pair.light, dark: pair.dark)
    }

    static func gradientBottom(_ categoryID: String) -> Color {
        gradientTop(categoryID)
            .opacity(FieldGuideCategoryAccentPresentation.gradientBottomRelativeIntensity)
    }

    /// Opaque hub-tile gradient stop — same hue/intensity as **`gradientBottom`**, no alpha.
    static func opaqueGradientBottom(_ categoryID: String) -> Color {
        AdaptiveAccentColor.color(
            light: FieldGuideCategoryAccentPresentation.lightGradientBottomRGB(for: categoryID),
            dark: FieldGuideCategoryAccentPresentation.darkGradientBottomRGB(for: categoryID)
        )
    }
}
