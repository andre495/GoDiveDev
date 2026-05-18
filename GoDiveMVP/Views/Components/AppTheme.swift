import SwiftUI
import UIKit

enum AppTheme {
    enum Colors {
        /// Flat mid-tone (e.g. small panels); full-bleed tab and **`AppPage`** roots use **`screenBackgroundGradient`**.
        static let surface = adaptive(
            light: UIColor(red: 0.98, green: 0.99, blue: 1.00, alpha: 1.0),
            dark: UIColor(red: 0.02, green: 0.06, blue: 0.10, alpha: 1.0)
        )
        static let surfaceElevated = adaptive(
            light: UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0),
            dark: UIColor(red: 0.05, green: 0.12, blue: 0.18, alpha: 1.0)
        )
        static let surfaceMuted = adaptive(
            light: UIColor(red: 0.93, green: 0.97, blue: 0.99, alpha: 1.0),
            dark: UIColor(red: 0.08, green: 0.16, blue: 0.23, alpha: 1.0)
        )

        /// Lighter **top** stop for full-screen backgrounds (ocean: shallower / brighter water above).
        /// **`LaunchScreenGradientTop`** in **Assets** mirrors this **light** stop for reference. **`LaunchScreen.storyboard`** uses a **single** inline **light** fill matching **`surfaceGradientBottom`** (see below).
        static let surfaceGradientTop = adaptive(
            light: UIColor(red: 0.99, green: 0.995, blue: 1.00, alpha: 1.0),
            dark: UIColor(red: 0.10, green: 0.17, blue: 0.26, alpha: 1.0)
        )
        /// Deeper **bottom** stop; dark mode reads as depth below the lighter band.
        /// **`LaunchScreen.storyboard`** solid background uses this **light** stop inline; **`LaunchScreenGradientBottom`** in **Assets** mirrors for reference / dark documentation.
        static let surfaceGradientBottom = adaptive(
            light: UIColor(red: 0.91, green: 0.95, blue: 0.98, alpha: 1.0),
            dark: UIColor(red: 0.02, green: 0.05, blue: 0.09, alpha: 1.0)
        )

        /// Full-bleed page chrome: **top → bottom**, lighter over deeper (both appearances).
        static var screenBackgroundGradient: LinearGradient {
            LinearGradient(
                colors: [surfaceGradientTop, surfaceGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        static let primaryText = adaptive(
            light: UIColor(red: 0.02, green: 0.12, blue: 0.20, alpha: 1.0),
            dark: UIColor(red: 0.92, green: 0.97, blue: 1.00, alpha: 1.0)
        )
        static let secondaryText = adaptive(
            light: UIColor(red: 0.27, green: 0.38, blue: 0.48, alpha: 1.0),
            dark: UIColor(red: 0.68, green: 0.78, blue: 0.86, alpha: 1.0)
        )
        static let mutedText = adaptive(
            light: UIColor(red: 0.50, green: 0.60, blue: 0.68, alpha: 1.0),
            dark: UIColor(red: 0.45, green: 0.56, blue: 0.64, alpha: 1.0)
        )

        static let accent = adaptive(
            light: UIColor(red: 0.00, green: 0.48, blue: 0.72, alpha: 1.0),
            dark: UIColor(red: 0.30, green: 0.76, blue: 1.00, alpha: 1.0)
        )
        static let accentDeep = adaptive(
            light: UIColor(red: 0.00, green: 0.18, blue: 0.36, alpha: 1.0),
            dark: UIColor(red: 0.64, green: 0.90, blue: 1.00, alpha: 1.0)
        )
        static let accentLight = adaptive(
            light: UIColor(red: 0.65, green: 0.88, blue: 1.00, alpha: 1.0),
            dark: UIColor(red: 0.10, green: 0.34, blue: 0.48, alpha: 1.0)
        )

        /// Tank gas chart line, cylinder O₂ band, and minimized **PSI / SAC / RMV** values.
        static let tankGasAccent = Color(red: 0.92, green: 0.78, blue: 0.12)

        static let headerGradientStart = accent
        static let headerGradientEnd = accentDeep
        static let headerBackground = surfaceElevated
        static let iconPrimary = accentDeep
        static let tabSelected = accent
        static let tabUnselected = secondaryText
        static let textPrimary = primaryText

        /// **GoDive** wordmark on **`AppHeader`**: shallow → mid → deep ocean (leading → trailing), inspired by legacy oceanBlue → deepBlue treatment.
        static var headerTitleForegroundGradient: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: accentLight, location: 0.0),
                    .init(color: accent, location: 0.48),
                    .init(color: accentDeep, location: 1.0),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        private static func adaptive(light: UIColor, dark: UIColor) -> Color {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? dark : light
            })
        }
    }

    enum Spacing {
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    enum Typography {
        /// **`AppHeader`** brand wordmark (legacy app used **`.largeTitle`**).
        static let headerBrandTitle: Font = .largeTitle
        static let headerTitle = Font.title
    }

    enum Layout {
        /// Fallback before **`AppHeader`** publishes its measured height (see **`AppHeaderMetrics.HeightKey`**). Sized for **`.largeTitle`** brand + vertical **`Spacing.md`** padding.
        static let appHeaderClearanceFallback: CGFloat = 72
    }

    /// Shared chrome for SwiftUI **`.sheet`** presentations (see **`appSheetPresentationChrome()`**).
    enum Sheet {
        static let cornerRadius: CGFloat = 20
        /// Opacity on **`.thinMaterial`** in **`presentationBackground`** — lower values let more of the hero / page show through.
        static let backgroundMaterialOpacity: CGFloat = 0.64
    }
}
