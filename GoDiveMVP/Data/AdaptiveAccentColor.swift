import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Trait-aware accent fill — darker / higher-contrast in light mode, pastel in dark mode.
enum AdaptiveAccentColor: Sendable {
    struct RGB: Sendable, Equatable {
        let red: Double
        let green: Double
        let blue: Double
    }

    nonisolated static func color(light: RGB, dark: RGB) -> Color {
        #if canImport(UIKit)
        Color(
            UIColor { traits in
                let rgb = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
            }
        )
        #else
        Color(red: light.red, green: light.green, blue: light.blue)
        #endif
    }
}
