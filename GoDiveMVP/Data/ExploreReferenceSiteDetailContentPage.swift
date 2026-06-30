import Foundation
import SwiftUI

/// Single-tab pager page on **`ExploreReferenceSiteDetailView`**.
enum ExploreReferenceSiteDetailContentPage: Hashable, Sendable, Identifiable {
    case details

    var id: Self { self }
}

enum ExploreReferenceSiteDetailContentPagerPresentation: Sendable {
    nonisolated static let pages: [ExploreReferenceSiteDetailContentPage] = [.details]

    nonisolated static var pageCount: Int { pages.count }

    nonisolated static var defaultPage: ExploreReferenceSiteDetailContentPage { .details }

    nonisolated static let detailsSectionTitle = "Details"

    nonisolated static func pageTitle(for page: ExploreReferenceSiteDetailContentPage) -> String {
        switch page {
        case .details:
            return detailsSectionTitle
        }
    }

    nonisolated static func accessibilityIdentifier(for page: ExploreReferenceSiteDetailContentPage) -> String {
        switch page {
        case .details:
            return "Explore.ReferenceSiteDetail.ContentPager.Details"
        }
    }

    nonisolated static func usesStaticPagerLayout(for page: ExploreReferenceSiteDetailContentPage) -> Bool {
        false
    }

    nonisolated static func staticPagerContentAlignment(
        for page: ExploreReferenceSiteDetailContentPage
    ) -> Alignment {
        .top
    }

    nonisolated static func pagerPageLayout(
        for page: ExploreReferenceSiteDetailContentPage
    ) -> BlueSheetDetailPagerPageLayout {
        BlueSheetDetailPagerPageLayout(
            usesStaticLayout: usesStaticPagerLayout(for: page),
            staticContentAlignment: staticPagerContentAlignment(for: page),
            accessibilityLabel: pageTitle(for: page),
            accessibilityIdentifier: accessibilityIdentifier(for: page)
        )
    }
}
