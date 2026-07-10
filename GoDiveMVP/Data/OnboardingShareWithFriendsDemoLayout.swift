import CoreGraphics
import Foundation

/// Geometry budget for the **Share with friends** onboarding phone-frame micro-demo.
enum OnboardingShareWithFriendsDemoLayout: Sendable {

    struct Metrics: Equatable, Sendable {
        let phoneSize: CGSize
        let statusBarInset: CGFloat
        let heroHeight: CGFloat
        let panelOverlap: CGFloat
        let blueSheetHeight: CGFloat
        let pinnedSummaryHeight: CGFloat
        let pagerHeight: CGFloat
        let pageIndicatorHeight: CGFloat
        let statTileHeight: CGFloat
        let statGridSpacing: CGFloat
        let buddyAvatarDiameter: CGFloat
        let shareCardFitSize: CGSize
    }

  nonisolated static func metrics(
    phoneSize: CGSize = OnboardingDemoPhoneFrameMetrics.referenceLogicalSize
  ) -> Metrics {
    let width = max(phoneSize.width, 1)
    let height = max(phoneSize.height, 1)

    let statusBarInset: CGFloat = 54
    let panelOverlap: CGFloat = 28
    let panelTopPadding: CGFloat = 12
    let panelBottomPadding: CGFloat = 6
    let pinnedToPagerGap: CGFloat = 6
    let pageIndicatorHeight: CGFloat = 20
    let pinnedSummaryHeight: CGFloat = 72

    let heroHeight = min(width * 0.68, height * 0.34)
    let blueSheetHeight = height - heroHeight + panelOverlap
    let pagerHeight = max(
      blueSheetHeight
        - panelTopPadding
        - panelBottomPadding
        - pinnedSummaryHeight
        - pinnedToPagerGap
        - pageIndicatorHeight,
      120
    )

    let statGridSpacing: CGFloat = 10
    let statRows: CGFloat = 2
    let statsTopPadding: CGFloat = 4
    let statTileHeight = min(
      68,
      max(
        52,
        floor((pagerHeight - statsTopPadding - statGridSpacing) / statRows)
      )
    )

    let buddyAvatarDiameter = min(56, max(48, statTileHeight * 0.78))

    let shareScale = min(
      width / TripShareCardPresentation.cardWidth,
      height / TripShareCardPresentation.cardMinHeight
    )
    let shareCardFitSize = CGSize(
      width: TripShareCardPresentation.cardWidth * shareScale,
      height: TripShareCardPresentation.cardMinHeight * shareScale
    )

    return Metrics(
      phoneSize: phoneSize,
      statusBarInset: statusBarInset,
      heroHeight: heroHeight,
      panelOverlap: panelOverlap,
      blueSheetHeight: blueSheetHeight,
      pinnedSummaryHeight: pinnedSummaryHeight,
      pagerHeight: pagerHeight,
      pageIndicatorHeight: pageIndicatorHeight,
      statTileHeight: statTileHeight,
      statGridSpacing: statGridSpacing,
      buddyAvatarDiameter: buddyAvatarDiameter,
      shareCardFitSize: shareCardFitSize
    )
  }

  nonisolated static func statsGridHeight(
    tileHeight: CGFloat,
    spacing: CGFloat,
    tileCount: Int = 4,
    columns: Int = 2
  ) -> CGFloat {
    guard tileCount > 0, columns > 0 else { return 0 }
    let rows = CGFloat((tileCount + columns - 1) / columns)
    return rows * tileHeight + max(rows - 1, 0) * spacing
  }
}
