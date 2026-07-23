import Foundation

/// Whether the blue sheet shell is a **tab root** (Home) or a **pushed detail** (buddy, trip, species, site).
enum BlueSheetPagePresentation: String, Sendable, CaseIterable, Identifiable {
    case tabRoot
    case pushedDetail

    var id: String { rawValue }

    var pageLayoutKind: PageLayoutKind {
        switch self {
        case .tabRoot: .home
        case .pushedDetail: .buddyDetail
        }
    }
}

/// Shared configuration for **`BlueSheetDetailPage`** and the planned **`BlueSheetTabRootPage`** (Home).
struct BlueSheetDetailPageConfiguration: Sendable, Equatable {
    let accessibilityRootIdentifier: String
    var presentation: BlueSheetPagePresentation
    var showsHero: Bool
    var hidesTabBarWhenPushed: Bool
    /// When **`true`**, sheet fill uses **`ProfileBubbleBackgroundLayer`** (bubbles + scrim) instead of the opaque overview blue.
    var usesProfileBubblePanelBackground: Bool
    /// When set, overrides **`bodyBottomPadding`** below the pinned summary (identity chrome pages).
    var pinnedSummaryBottomPadding: CGFloat?

    nonisolated static func pushedDetail(
        accessibilityRootIdentifier: String,
        showsHero: Bool = true,
        hidesTabBarWhenPushed: Bool = true,
        usesProfileBubblePanelBackground: Bool = false,
        pinnedSummaryBottomPadding: CGFloat? = nil
    ) -> Self {
        Self(
            accessibilityRootIdentifier: accessibilityRootIdentifier,
            presentation: .pushedDetail,
            showsHero: showsHero,
            hidesTabBarWhenPushed: hidesTabBarWhenPushed,
            usesProfileBubblePanelBackground: usesProfileBubblePanelBackground,
            pinnedSummaryBottomPadding: pinnedSummaryBottomPadding
        )
    }

    nonisolated static func tabRoot(
        accessibilityRootIdentifier: String,
        showsHero: Bool = true
    ) -> Self {
        Self(
            accessibilityRootIdentifier: accessibilityRootIdentifier,
            presentation: .tabRoot,
            showsHero: showsHero,
            hidesTabBarWhenPushed: false,
            usesProfileBubblePanelBackground: false,
            pinnedSummaryBottomPadding: nil
        )
    }

    /// Back-compat alias for pushed detail pages.
    nonisolated static func standard(
        accessibilityRootIdentifier: String,
        showsHero: Bool = true,
        hidesTabBarWhenPushed: Bool = true,
        usesProfileBubblePanelBackground: Bool = false,
        pinnedSummaryBottomPadding: CGFloat? = nil
    ) -> Self {
        pushedDetail(
            accessibilityRootIdentifier: accessibilityRootIdentifier,
            showsHero: showsHero,
            hidesTabBarWhenPushed: hidesTabBarWhenPushed,
            usesProfileBubblePanelBackground: usesProfileBubblePanelBackground,
            pinnedSummaryBottomPadding: pinnedSummaryBottomPadding
        )
    }

    /// Pushed catalog-style detail (sites, species, gear, certs) — same pinned-summary → pager clearance as profile / buddy identity pages; not Home tab root.
    nonisolated static func pushedDetailWithStandardPanelBodySpacing(
        accessibilityRootIdentifier: String,
        showsHero: Bool = true,
        hidesTabBarWhenPushed: Bool = true
    ) -> Self {
        pushedDetail(
            accessibilityRootIdentifier: accessibilityRootIdentifier,
            showsHero: showsHero,
            hidesTabBarWhenPushed: hidesTabBarWhenPushed,
            pinnedSummaryBottomPadding: BlueSheetDetailPagePinnedSummaryPresentation
                .pushedDetailPinnedSummaryBottomPadding
        )
    }
}

/// Pinned summary + pager horizontal inset inside the blue sheet panel (matches logbook / catalog list content).
enum BlueSheetDetailPagePinnedSummaryPresentation: Sendable {
    nonisolated static let horizontalPadding: CGFloat = AppTheme.Spacing.lg

    /// Blue-sheet seam → first pinned row (title or top accessory row).
    nonisolated static let seamTopPadding: CGFloat = AppTheme.Spacing.md
    /// Last pinned row → pager / panel body (default; identity / catalog pushed pages add **`panelBodyTopSpacingAdjustment`**).
    nonisolated static let bodyBottomPadding: CGFloat = AppTheme.Spacing.md
    /// Extra clearance below pinned summary before pager body on pushed detail pages (not Home tab root).
    nonisolated static let panelBodyTopSpacingAdjustment: CGFloat = 30
    /// Layout-lab handoff — moves **`BlueSheetDetailPanelContentTopDivider`** (negative pulls the line up).
    nonisolated static let panelContentTopDividerVerticalAdjustment: CGFloat = -21
    nonisolated static var pushedDetailPinnedSummaryBottomPadding: CGFloat {
        max(
            0,
            bodyBottomPadding
                + panelBodyTopSpacingAdjustment
                + panelContentTopDividerVerticalAdjustment
        )
    }
    /// Pinned summary → divider when no identity / catalog override is set.
    nonisolated static var defaultPinnedSummaryBottomPaddingBeforeDivider: CGFloat {
        max(0, bodyBottomPadding + panelContentTopDividerVerticalAdjustment)
    }
    /// Stacked pinned rows (accent, title, subtitle, **`topRow`**).
    nonisolated static let pinnedRowSpacing: CGFloat = AppTheme.Spacing.sm

    /// Back-compat aliases used by **`BlueSheetDetailPage`**.
    nonisolated static let topPadding: CGFloat = seamTopPadding
    nonisolated static let bottomPadding: CGFloat = bodyBottomPadding

    nonisolated static var pinnedSummaryAccessibilitySuffix: String { "PinnedSummary" }
}
