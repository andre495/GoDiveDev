import SwiftUI
import UIKit

enum AppTheme {
    enum Colors {
        /// Flat mid-tone (e.g. small panels); full-bleed tab and **`AppPage`** roots use **`screenBackgroundGradient`**.
        static let surface = adaptive(
            light: UIColor(red: 0.70, green: 0.84, blue: 0.92, alpha: 1.0),
            dark: UIColor(red: 0.02, green: 0.06, blue: 0.10, alpha: 1.0)
        )
        static let surfaceElevated = adaptive(
            light: UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0),
            dark: UIColor(red: 0.05, green: 0.12, blue: 0.18, alpha: 1.0)
        )
        static let surfaceMuted = adaptive(
            light: UIColor(red: 0.76, green: 0.87, blue: 0.93, alpha: 1.0),
            dark: UIColor(red: 0.08, green: 0.16, blue: 0.23, alpha: 1.0)
        )

        /// Lighter **top** stop for full-screen backgrounds (ocean: shallower / brighter water above).
        /// **`LaunchScreenGradientTop`** in **Assets** mirrors this **light** stop for reference. **`LaunchScreen.storyboard`** uses fixed **dark** fill from **`AppLaunchLayout`** (not appearance-adaptive).
        static let surfaceGradientTop = adaptive(
            light: UIColor(red: 0.74, green: 0.87, blue: 0.94, alpha: 1.0),
            dark: UIColor(red: 0.10, green: 0.17, blue: 0.26, alpha: 1.0)
        )
        /// Deeper **bottom** stop; dark mode reads as depth below the lighter band.
        /// **`LaunchScreen.storyboard`** solid background uses fixed **dark** inline sRGB (see **`AppLaunchLayout`**); **`LaunchScreenGradientBottom`** in **Assets** mirrors the same stop.
        static let surfaceGradientBottom = adaptive(
            light: UIColor(red: 0.58, green: 0.74, blue: 0.88, alpha: 1.0),
            dark: UIColor(red: 0.02, green: 0.05, blue: 0.09, alpha: 1.0)
        )
        /// Alias for in-app pages; **`LaunchScreen.storyboard`** + **`AppLaunchOverlay`** use fixed dark **`AppLaunchLayout`** colors instead.
        static let launchScreenBackground = surfaceGradientBottom

        /// Full-bleed page chrome: **top → bottom**, lighter over deeper (both appearances).
        static var screenBackgroundGradient: LinearGradient {
            LinearGradient(
                colors: [surfaceGradientTop, surfaceGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        /// Canvas fill behind **`WaterBubbleBackground`** rising bubbles.
        static let waterBubbleBackdrop = adaptive(
            light: UIColor(red: 0.68, green: 0.82, blue: 0.91, alpha: 1.0),
            dark: UIColor(red: 0.08, green: 0.14, blue: 0.22, alpha: 1.0)
        )

        /// Dark top feather for status bar / **GoDive** header readability — same in light and dark mode.
        static var statusBarEdgeScrimGradient: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.90), location: 0.0),
                    .init(color: Color.black.opacity(0.58), location: 0.52),
                    .init(color: Color.black.opacity(0.22), location: 0.82),
                    .init(color: Color.clear, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        /// Tall dark fade over scrolling lists under logbook / field guide / explore chrome.
        static var logbookTopChromeScrimGradient: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.90), location: 0.0),
                    .init(color: Color.black.opacity(0.72), location: 0.24),
                    .init(color: Color.black.opacity(0.48), location: 0.48),
                    .init(color: Color.black.opacity(0.20), location: 0.72),
                    .init(color: Color.clear, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        /// Solid band when **Reduce Transparency** is on (status bar region).
        static let statusBarEdgeScrimSolid = Color.black.opacity(0.88)

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
        /// Linked catalog site name on dive overview — flat mid ocean blue (not brand gradient / adaptive cyan).
        static let linkedSiteTitleAccent = Color(red: 0.00, green: 0.48, blue: 0.72)
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
        /// Inner height of **`CatalogSearchField`** in list top chrome (logbook, field guide, explore).
        static let logbookSearchFieldHeight: CGFloat = 44
        /// Fixed height for one **`ExploreDiveSiteRow`** tile in the Explore map search dropdown.
        static let exploreMapSearchSuggestionRowHeight: CGFloat = 88
        /// Number of suggestion tiles visible before scrolling.
        static let exploreMapSearchSuggestionVisibleRows: Int = 4

        static var exploreMapSearchSuggestionPanelHeight: CGFloat {
            let rows = CGFloat(exploreMapSearchSuggestionVisibleRows)
            let spacing = AppTheme.Spacing.md
            return rows * exploreMapSearchSuggestionRowHeight + max(0, rows - 1) * spacing
        }
    }

    /// Shared oval search field chrome (**`CatalogSearchField`**).
    enum SearchField {
        static let outlineColor = Colors.accent.opacity(0.38)
        static let outlineFocusedColor = Colors.accent.opacity(0.62)
        static let outlineWidth: CGFloat = 1
        static let outlineFocusedWidth: CGFloat = 1.5
    }

    /// Shared chrome for SwiftUI **`.sheet`** presentations (see **`appSheetPresentationChrome()`**).
    enum Sheet {
        static let cornerRadius: CGFloat = 20
        /// Extra space between the system (or embedded) grabber and the first row of sheet content.
        static let contentTopSpacing: CGFloat = Spacing.lg
        /// Opacity on **`.thinMaterial`** in **`presentationBackground`** — lower values let more of the hero / page show through.
        static let backgroundMaterialOpacity: CGFloat = 0.64
        /// **Media** embedded panel at every detent — hero shows through the frosted sheet.
        static let embeddedOverviewTranslucentOpacity: CGFloat = 0.62
    }
}
