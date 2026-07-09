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

    nonisolated static func pushedDetail(
        accessibilityRootIdentifier: String,
        showsHero: Bool = true,
        hidesTabBarWhenPushed: Bool = true
    ) -> Self {
        Self(
            accessibilityRootIdentifier: accessibilityRootIdentifier,
            presentation: .pushedDetail,
            showsHero: showsHero,
            hidesTabBarWhenPushed: hidesTabBarWhenPushed
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
            hidesTabBarWhenPushed: false
        )
    }

    /// Back-compat alias for pushed detail pages.
    nonisolated static func standard(
        accessibilityRootIdentifier: String,
        showsHero: Bool = true,
        hidesTabBarWhenPushed: Bool = true
    ) -> Self {
        pushedDetail(
            accessibilityRootIdentifier: accessibilityRootIdentifier,
            showsHero: showsHero,
            hidesTabBarWhenPushed: hidesTabBarWhenPushed
        )
    }
}

/// Pinned summary + pager horizontal inset inside the blue sheet panel (matches logbook / catalog list content).
enum BlueSheetDetailPagePinnedSummaryPresentation: Sendable {
    nonisolated static let horizontalPadding: CGFloat = AppTheme.Spacing.lg

    /// Blue-sheet seam → first pinned row (title or top accessory row).
    nonisolated static let seamTopPadding: CGFloat = AppTheme.Spacing.md
    /// Last pinned row → pager / panel body.
    nonisolated static let bodyBottomPadding: CGFloat = AppTheme.Spacing.md
    /// Stacked pinned rows (accent, title, subtitle, **`topRow`**).
    nonisolated static let pinnedRowSpacing: CGFloat = AppTheme.Spacing.sm

    /// Back-compat aliases used by **`BlueSheetDetailPage`**.
    nonisolated static let topPadding: CGFloat = seamTopPadding
    nonisolated static let bottomPadding: CGFloat = bodyBottomPadding

    nonisolated static var pinnedSummaryAccessibilitySuffix: String { "PinnedSummary" }
}
