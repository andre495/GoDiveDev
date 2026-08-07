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

    /// Content-area titles are pinned above the scroll/static body via **`BlueSheetDetailPager`**.
    nonisolated static let showsPinnedPageHeaders = true

    /// Same 2-column mosaic as Field Guide subcategory browse / trip marine life.
    nonisolated static let similarSpeciesGridColumnCount = 2

    /// In-page title above each page’s body (pager dots keep shorter **`pageTitle`** labels).
    nonisolated static func pageSubtitle(for page: FieldGuideSpeciesDetailContentPage) -> String {
        switch page {
        case .about:
            return "About"
        case .stats:
            return "Size and Range"
        case .similarSpecies:
            return "Related Species"
        case .taggedDives:
            return "Tagged Dives"
        case .taggedMedia:
            return "Tagged Media"
        }
    }

    nonisolated static var similarSpeciesPageSubtitle: String {
        pageSubtitle(for: .similarSpecies)
    }

    nonisolated static func pageSubtitleAccessibilityIdentifier(
        for page: FieldGuideSpeciesDetailContentPage
    ) -> String {
        switch page {
        case .about:
            return "FieldGuide.SpeciesDetail.About.Subtitle"
        case .stats:
            return "FieldGuide.SpeciesDetail.Stats.Subtitle"
        case .similarSpecies:
            return "FieldGuide.SpeciesDetail.SimilarSpecies.Subtitle"
        case .taggedDives:
            return "FieldGuide.SpeciesDetail.TaggedDives.Subtitle"
        case .taggedMedia:
            return "FieldGuide.SpeciesDetail.TaggedMedia.Subtitle"
        }
    }

    nonisolated static func similarSpeciesTileAccessibilityIdentifier(uuid: String) -> String {
        "FieldGuide.SpeciesDetail.SimilarSpecies.\(uuid)"
    }

    nonisolated static func pagerPageLayout(for page: FieldGuideSpeciesDetailContentPage) -> BlueSheetDetailPagerPageLayout {
        BlueSheetDetailPagerPageLayout(
            usesStaticLayout: usesStaticPagerLayout(for: page),
            staticContentAlignment: staticPagerContentAlignment(for: page),
            accessibilityLabel: pageTitle(for: page),
            accessibilityIdentifier: accessibilityIdentifier(for: page)
        )
    }
}
