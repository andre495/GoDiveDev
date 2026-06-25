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
            light: UIColor(red: 0.84, green: 0.89, blue: 0.94, alpha: 1.0),
            dark: UIColor(red: 0.05, green: 0.12, blue: 0.18, alpha: 1.0)
        )
        static let surfaceMuted = adaptive(
            light: UIColor(red: 0.20, green: 0.34, blue: 0.48, alpha: 1.0),
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

        /// Semitransparent veil over **`WaterBubbleBackground`** on **`ProfileView`**.
        static let profileBubbleScrim = adaptive(
            light: UIColor(red: 0.62, green: 0.76, blue: 0.88, alpha: 0.64),
            dark: UIColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 0.48)
        )

        /// Pale ocean status-bar feather in light mode; deep ocean in dark (**`AppStatusBarEdgeScrim`** on Home / Logbook **`AppHeader`**).
        static let headerScrimBase = adaptive(
            light: UIColor(red: 0.74, green: 0.87, blue: 0.94, alpha: 1.0),
            dark: UIColor(red: 0.02, green: 0.05, blue: 0.09, alpha: 1.0)
        )

        /// Top feather for status bar / **GoDive** header readability — tall, mostly transparent; peaks at **`AppStatusBarEdgeScrimMetrics.brandHeaderMaxScrimOpacity`**.
        static var statusBarEdgeScrimGradient: LinearGradient {
            let peak = AppStatusBarEdgeScrimMetrics.brandHeaderMaxScrimOpacity
            return LinearGradient(
                stops: [
                    .init(color: headerScrimBase.opacity(peak), location: 0.0),
                    .init(color: headerScrimBase.opacity(peak * 0.38), location: 0.12),
                    .init(color: headerScrimBase.opacity(peak * 0.30), location: 0.42),
                    .init(color: headerScrimBase.opacity(peak * 0.18), location: 0.72),
                    .init(color: headerScrimBase.opacity(peak * 0.08), location: 0.90),
                    .init(color: Color.clear, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        /// Tall ocean fade over scrolling lists under logbook / field guide / explore chrome (matches **`headerScrimBase`**).
        static let listTopChromeScrimBase = headerScrimBase

        static var logbookTopChromeScrimGradient: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: listTopChromeScrimBase.opacity(0.95), location: 0.0),
                    .init(color: listTopChromeScrimBase.opacity(0.76), location: 0.24),
                    .init(color: listTopChromeScrimBase.opacity(0.52), location: 0.48),
                    .init(color: listTopChromeScrimBase.opacity(0.22), location: 0.72),
                    .init(color: Color.clear, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        /// Solid list chrome when **Reduce Transparency** is on (**`LogbookTopChromeScrim`**).
        static var listTopChromeScrimSolid: Color {
            listTopChromeScrimBase.opacity(0.98)
        }

        /// Short status-bar feather for scroll-under list pages (certifications, buddies, equipment locker).
        static var listStatusBarEdgeScrimGradient: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: listTopChromeScrimBase.opacity(0.96), location: 0.0),
                    .init(color: listTopChromeScrimBase.opacity(0.72), location: 0.45),
                    .init(color: listTopChromeScrimBase.opacity(0.34), location: 0.78),
                    .init(color: Color.clear, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        /// Solid status bar on list pages when **Reduce Transparency** is on.
        static var listStatusBarEdgeScrimSolid: Color {
            listTopChromeScrimBase.opacity(0.94)
        }

        /// Solid band when **Reduce Transparency** is on (status bar region).
        static var statusBarEdgeScrimSolid: Color {
            headerScrimBase.opacity(AppStatusBarEdgeScrimMetrics.brandHeaderMaxScrimOpacity)
        }

        /// Deep ocean fade over map imagery (**Explore** map in light mode) — **`surfaceGradientBottom`**.
        static let mapChromeScrimBase = surfaceGradientBottom

        /// Status-bar feather on **Explore** map (light mode).
        static var exploreMapStatusBarEdgeScrimGradient: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: mapChromeScrimBase.opacity(0.96), location: 0.0),
                    .init(color: mapChromeScrimBase.opacity(0.72), location: 0.45),
                    .init(color: mapChromeScrimBase.opacity(0.34), location: 0.78),
                    .init(color: Color.clear, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        /// Tall fade under **Explore** map chrome (light mode).
        static var exploreMapTopChromeScrimGradient: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: mapChromeScrimBase.opacity(0.95), location: 0.0),
                    .init(color: mapChromeScrimBase.opacity(0.76), location: 0.24),
                    .init(color: mapChromeScrimBase.opacity(0.52), location: 0.48),
                    .init(color: mapChromeScrimBase.opacity(0.22), location: 0.72),
                    .init(color: Color.clear, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        /// Solid **Explore** map chrome when **Reduce Transparency** is on (light mode).
        static var exploreMapTopChromeScrimSolid: Color {
            mapChromeScrimBase.opacity(0.98)
        }

        static var exploreMapStatusBarEdgeScrimSolid: Color {
            mapChromeScrimBase.opacity(0.94)
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
        /// Linked catalog site name on dive overview — flat mid ocean blue (not brand gradient / adaptive cyan).
        static let linkedSiteTitleAccent = Color(red: 0.00, green: 0.48, blue: 0.72)
        static let accentDeep = adaptive(
            light: UIColor(red: 0.00, green: 0.18, blue: 0.36, alpha: 1.0),
            dark: UIColor(red: 0.64, green: 0.90, blue: 1.00, alpha: 1.0)
        )
        static let accentLight = adaptive(
            light: UIColor(red: 0.42, green: 0.68, blue: 0.90, alpha: 1.0),
            dark: UIColor(red: 0.10, green: 0.34, blue: 0.48, alpha: 1.0)
        )

        /// Semitransparent slate fill for Explore search + **My sites / All** toggle (light mode).
        static let exploreChromeControlFill = adaptive(
            light: UIColor(red: 0.27, green: 0.38, blue: 0.48, alpha: 0.38),
            dark: UIColor(red: 0.05, green: 0.12, blue: 0.18, alpha: 0.78)
        )
        /// Deprecated — prefer **`appLiquidGlassSearchFieldChrome()`** on **`CatalogSearchField`**.

        /// Tank gas chart line, cylinder O₂ band, and minimized **PSI / SAC / RMV** values.
        static let tankGasAccent = Color(red: 0.92, green: 0.78, blue: 0.12)

        /// Transparent stat / highlight tiles — legacy outline token (prefer **`AppListTileCardChrome`** stroke).
        static let highlightTileOutline = adaptive(
            light: UIColor(red: 0.12, green: 0.26, blue: 0.40, alpha: 0.88),
            dark: UIColor(red: 0.38, green: 0.54, blue: 0.68, alpha: 0.72)
        )

        static let headerGradientStart = accent
        static let headerGradientEnd = accentDeep
        static let headerBackground = surfaceElevated
        static let iconPrimary = accentDeep
        static let tabSelected = accent
        static let tabUnselected = secondaryText
        /// Liquid Glass back chevron — dark slate in light mode, white in dark mode.
        static let backButtonForeground = adaptive(
            light: UIColor(red: 0.12, green: 0.26, blue: 0.40, alpha: 1.0),
            dark: UIColor(white: 1.0, alpha: 0.96)
        )
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

    /// Shared outline for highlight tiles (corner radius only — fill/stroke live in **`AppListTileCardChrome`**).
    enum HighlightTile {
        static let cornerRadius: CGFloat = 12
        static let outlineWidth: CGFloat = 1.25
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
        /// Top inset below the status safe area for **`AppHeader`** (wordmark / profile / back row).
        static let appHeaderTopPadding: CGFloat = Spacing.sm
        /// Bottom inset below the **`AppHeader`** row.
        static let appHeaderBottomPadding: CGFloat = Spacing.md
        /// Fallback before top chrome publishes its measured height (see **`AppHeaderMetrics.HeightKey`**). Sized for **`.largeTitle`** **`AppHeader`**; search-only rows measure shorter at runtime.
        static let appHeaderClearanceFallback: CGFloat = 64
        /// Shared height for Liquid Glass search capsules and toolbar icon / text buttons in top chrome.
        static let glassChromeControlHeight: CGFloat = 44
        /// Inner height of **`CatalogSearchField`** in list top chrome (logbook, field guide, explore).
        static let logbookSearchFieldHeight: CGFloat = glassChromeControlHeight
        /// Fixed height for one **`ExploreDiveSiteRow`** tile in the Explore map search dropdown.
        static let exploreMapSearchSuggestionRowHeight: CGFloat = 88
        /// Number of suggestion tiles visible before scrolling.
        static let exploreMapSearchSuggestionVisibleRows: Int = 3

        static func exploreMapSearchSuggestionPanelHeight(rowCount: Int) -> CGFloat {
            let cappedRows = min(max(rowCount, 0), exploreMapSearchSuggestionVisibleRows)
            guard cappedRows > 0 else { return 0 }
            let rows = CGFloat(cappedRows)
            let spacing = AppTheme.Spacing.md
            return rows * exploreMapSearchSuggestionRowHeight + max(0, rows - 1) * spacing
        }

        static var exploreMapSearchSuggestionPanelHeight: CGFloat {
            exploreMapSearchSuggestionPanelHeight(rowCount: exploreMapSearchSuggestionVisibleRows)
        }
    }

    /// Legacy oval outline tokens — **`CatalogSearchField`** uses Liquid Glass instead.
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

extension View {
    /// Vertical padding shared by **`AppHeader`** and tab top chrome (search rows / icon actions).
    func appTopChromeVerticalPadding() -> some View {
        padding(.top, AppTheme.Layout.appHeaderTopPadding)
            .padding(.bottom, AppTheme.Layout.appHeaderBottomPadding)
    }
}
