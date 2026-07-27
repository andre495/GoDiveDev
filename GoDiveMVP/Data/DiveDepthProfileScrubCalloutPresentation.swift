import CoreGraphics
import Foundation

/// Active depth-profile scrub readout (time, depth, optional pressure).
struct DiveDepthProfileScrubCallout: Equatable, Sendable {
    let elapsedSeconds: Double
    let depthMeters: Double
    let pressurePSI: Double?
}

/// Where the scrub callout is drawn while the line + dots follow the finger.
enum DiveDepthProfileScrubCalloutPinning: Sendable, Equatable {
    case followFinger
    case pinnedUnderTabMenu(topObstructionHeight: CGFloat)
}

enum DiveDepthProfileScrubCalloutPresentation: Sendable {
    /// Space between the dive icon tab bar and the pinned scrub label.
    nonisolated static let gapBelowTabMenu: CGFloat = 10

    /// **`DiveActivityIconTabBar`** glass shell padding above + below the **44** pt segments.
    nonisolated static let iconTabBarShellVerticalInset: CGFloat = 8

    /// Icon tab row height including shell padding (**52** pt with default segment size).
    nonisolated static let iconTabBarChromeRowHeight: CGFloat = 44 + iconTabBarShellVerticalInset

    nonisolated static func labelTopPadding(
        topSafeInset: CGFloat,
        chromeTopPadding: CGFloat
    ) -> CGFloat {
        topSafeInset
            + chromeTopPadding
            + iconTabBarChromeRowHeight
            + gapBelowTabMenu
    }

    /// Prefer **`labelTopPadding(topSafeInset:chromeTopPadding:)`** — **`mapTopObstructionHeight`** omits tab-bar shell padding.
    nonisolated static func labelTopPadding(topObstructionHeight: CGFloat) -> CGFloat {
        topObstructionHeight + iconTabBarShellVerticalInset + gapBelowTabMenu
    }

    /// Portrait tank **minimized** — sit in the chart's top fade band (not under the icon tab bar).
    nonisolated static func labelTopPaddingPinnedAtMinimizedPortraitChartFade(
        chartFrame: CGRect,
        topFadeFraction: CGFloat = DiveTankOverviewHeroPresentation.minimizedPortraitChartTopFadeFraction
    ) -> CGFloat {
        let fadeBandHeight = chartFrame.height * topFadeFraction
        let insetBelowChartTop = max(6, fadeBandHeight * 0.4)
        return chartFrame.minY + insetBelowChartTop
    }
}
