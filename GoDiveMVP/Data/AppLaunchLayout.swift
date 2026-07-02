import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

/// Shared launch branding layout — keep in sync with **`LaunchScreen.storyboard`** constraints.
///
/// Pure **CoreGraphics** math — **`nonisolated`** so **`AppLaunchOverlay`** and tests stay off the main actor (Swift 6).
enum AppLaunchLayout: Sendable {
    nonisolated static let logoSize: CGFloat = 128
    /// Logo **`centerY`** = safe-area vertical midpoint + this constant (storyboard **`-48`**).
    nonisolated static let logoCenterYOffsetFromSafeAreaCenter: CGFloat = -48
    nonisolated static let logoToTitleSpacing: CGFloat = 24
    /// Matches **`AppTheme.Typography.headerBrandTitle`** (UIKit **`.largeTitle`**, bold) at the current content size.
    nonisolated static var titleFontSize: CGFloat {
        #if canImport(UIKit)
        launchTitleUIFont().pointSize
        #else
        34
        #endif
    }
    /// Measured **`UILabel`** line height for the launch title font (storyboard + overlay positioning).
    nonisolated static var titleLineHeight: CGFloat {
        #if canImport(UIKit)
        ceil(launchTitleUIFont().lineHeight)
        #else
        41
        #endif
    }
    nonisolated static let progressTopSpacing: CGFloat = 8

    // MARK: - Fixed dark splash (storyboard + overlay; ignores Light/Dark Mode)

    /// Matches **`AppTheme.Colors.surfaceGradientBottom`** dark + **`LaunchScreen.storyboard`** inline fill.
    nonisolated static let fixedBackgroundRed: CGFloat = 0.02
    nonisolated static let fixedBackgroundGreen: CGFloat = 0.05
    nonisolated static let fixedBackgroundBlue: CGFloat = 0.09
    /// Matches dark **`AppTheme.Colors.accent`** / **`LaunchScreenTitle`** dark stop.
    nonisolated static let fixedTitleRed: CGFloat = 0.30
    nonisolated static let fixedTitleGreen: CGFloat = 0.76
    nonisolated static let fixedTitleBlue: CGFloat = 1.0

    nonisolated static func safeAreaMidY(
        viewHeight: CGFloat,
        safeAreaTop: CGFloat,
        safeAreaBottom: CGFloat
    ) -> CGFloat {
        guard viewHeight > safeAreaTop + safeAreaBottom else { return viewHeight / 2 }
        return safeAreaTop + (viewHeight - safeAreaTop - safeAreaBottom) / 2
    }

    nonisolated static func logoCenterY(safeAreaMidY: CGFloat) -> CGFloat {
        safeAreaMidY + logoCenterYOffsetFromSafeAreaCenter
    }

    nonisolated static func titleCenterY(logoCenterY: CGFloat) -> CGFloat {
        logoCenterY + logoSize / 2 + logoToTitleSpacing + titleLineHeight / 2
    }

    nonisolated static func progressCenterY(titleCenterY: CGFloat, progressHeight: CGFloat = 20) -> CGFloat {
        titleCenterY + titleLineHeight / 2 + progressTopSpacing + progressHeight / 2
    }

    #if canImport(UIKit)
    nonisolated private static func launchTitleUIFont() -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: .largeTitle)
        return UIFont.boldSystemFont(ofSize: base.pointSize)
    }
    #endif
}
