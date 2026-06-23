import Foundation
import SwiftUI

/// Horizontal pager pages on **`FieldGuideMarineLifeDetailView`** (below pinned name block).
enum FieldGuideSpeciesDetailContentPage: Hashable, Sendable, Identifiable {
    case about
    case stats
    case taggedDives
    case taggedMedia

    var id: Self { self }
}

enum FieldGuideSpeciesDetailContentPagerPresentation: Sendable {

    nonisolated static let pages: [FieldGuideSpeciesDetailContentPage] = [
        .about,
        .stats,
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
}
