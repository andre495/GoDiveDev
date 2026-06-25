import Foundation
import SwiftUI

/// Horizontal pager pages on **`ExploreDiveSiteDetailView`** (below pinned site title).
enum ExploreDiveSiteDetailContentPage: Hashable, Sendable, Identifiable {
    case diveDetails
    case divesHere
    case marineLifeHere
    case taggedMedia

    var id: Self { self }
}

extension ExploreDiveSiteDetailContentPage: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.diveDetails, .diveDetails): true
        case (.divesHere, .divesHere): true
        case (.marineLifeHere, .marineLifeHere): true
        case (.taggedMedia, .taggedMedia): true
        default: false
        }
    }
}

enum ExploreDiveSiteDetailContentPagerPresentation: Sendable {

    nonisolated static let pages: [ExploreDiveSiteDetailContentPage] = [
        .diveDetails,
        .divesHere,
        .marineLifeHere,
        .taggedMedia,
    ]

    nonisolated static var pageCount: Int {
        pages.count
    }

    nonisolated static var defaultPage: ExploreDiveSiteDetailContentPage {
        .diveDetails
    }

    nonisolated static let diveDetailsSectionTitle = "Dive details"
    nonisolated static let divesHereSectionTitle = "Dives here"
    nonisolated static let marineLifeHereSectionTitle = "Marine life here"
    nonisolated static let taggedMediaSectionTitle = "Tagged media"

    nonisolated static func pageTitle(for page: ExploreDiveSiteDetailContentPage) -> String {
        switch page {
        case .diveDetails:
            return diveDetailsSectionTitle
        case .divesHere:
            return divesHereSectionTitle
        case .marineLifeHere:
            return marineLifeHereSectionTitle
        case .taggedMedia:
            return taggedMediaSectionTitle
        }
    }

    nonisolated static func emptyStateMessage(for page: ExploreDiveSiteDetailContentPage) -> String {
        switch page {
        case .diveDetails:
            return ""
        case .divesHere:
            return "No dives logged at this site yet."
        case .marineLifeHere:
            return "No marine life logged at this site yet."
        case .taggedMedia:
            return "No photos or videos from dives at this site yet."
        }
    }

    nonisolated static func accessibilityIdentifier(for page: ExploreDiveSiteDetailContentPage) -> String {
        switch page {
        case .diveDetails:
            return "Explore.DiveSiteDetail.ContentPager.DiveDetails"
        case .divesHere:
            return "Explore.DiveSiteDetail.ContentPager.DivesHere"
        case .marineLifeHere:
            return "Explore.DiveSiteDetail.ContentPager.MarineLifeHere"
        case .taggedMedia:
            return "Explore.DiveSiteDetail.ContentPager.TaggedMedia"
        }
    }

    nonisolated static func usesStaticPagerLayout(for page: ExploreDiveSiteDetailContentPage) -> Bool {
        false
    }

    nonisolated static func staticPagerContentAlignment(for page: ExploreDiveSiteDetailContentPage) -> Alignment {
        .top
    }

    nonisolated static let showsPinnedPageHeaders = false
}
