import Foundation
import SwiftUI

/// Horizontal pager pages on **`FieldGuideMarineLifeDetailView`** (below pinned name block).
enum FieldGuideSpeciesDetailContentPage: Hashable, Sendable, Identifiable {
    case about
    case stats
    case similarSpecies
    case taggedDives
    case taggedMedia

    var id: Self { self }
}

enum FieldGuideSpeciesDetailContentPagerPresentation: Sendable {

    nonisolated static let pages: [FieldGuideSpeciesDetailContentPage] = [
        .about,
        .stats,
        .similarSpecies,
        .taggedDives,
        .taggedMedia,
    ]

    nonisolated static var pageCount: Int {
        pages.count
    }

    nonisolated static var defaultPage: FieldGuideSpeciesDetailContentPage {
        .about
    }

    nonisolated static func pageTitle(for page: FieldGuideSpeciesDetailContentPage) -> String {
        switch page {
        case .about:
            return "About"
        case .stats:
            return "Size and range"
        case .similarSpecies:
            return "Similar species"
        case .taggedDives:
            return "Tagged dives"
        case .taggedMedia:
            return "Tagged media"
        }
    }

    nonisolated static func emptyStateMessage(for page: FieldGuideSpeciesDetailContentPage) -> String {
        switch page {
        case .about:
            return "No description available for this species yet."
        case .stats:
            return ""
        case .similarSpecies:
            return "No similar species found in the catalog yet."
        case .taggedDives:
            return "No dives tagged with this species yet."
        case .taggedMedia:
            return "No photos or videos tagged with this species yet."
        }
    }

    nonisolated static func accessibilityIdentifier(for page: FieldGuideSpeciesDetailContentPage) -> String {
        switch page {
        case .about:
            return "FieldGuide.SpeciesDetail.ContentPager.About"
        case .stats:
            return "FieldGuide.SpeciesDetail.ContentPager.Stats"
        case .similarSpecies:
            return "FieldGuide.SpeciesDetail.ContentPager.SimilarSpecies"
        case .taggedDives:
            return "FieldGuide.SpeciesDetail.ContentPager.TaggedDives"
        case .taggedMedia:
            return "FieldGuide.SpeciesDetail.ContentPager.TaggedMedia"
        }
    }

    nonisolated static func usesStaticPagerLayout(for page: FieldGuideSpeciesDetailContentPage) -> Bool {
        false
    }

    nonisolated static func staticPagerContentAlignment(for page: FieldGuideSpeciesDetailContentPage) -> Alignment {
        .top
    }

    nonisolated static let showsPinnedPageHeaders = false

    nonisolated static func pagerPageLayout(for page: FieldGuideSpeciesDetailContentPage) -> BlueSheetDetailPagerPageLayout {
        BlueSheetDetailPagerPageLayout(
            usesStaticLayout: usesStaticPagerLayout(for: page),
            staticContentAlignment: staticPagerContentAlignment(for: page),
            accessibilityLabel: pageTitle(for: page),
            accessibilityIdentifier: accessibilityIdentifier(for: page)
        )
    }
}
