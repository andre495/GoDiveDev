import Foundation
import SwiftUI

/// Horizontal pager pages on **`ActivityTagDetailView`**.
enum ActivityTagDetailContentPage: Hashable, Sendable, Identifiable {
    case stats
    case activities
    case marineLife
    case buddies
    case media

    var id: Self { self }
}

enum ActivityTagDetailContentPagerPresentation: Sendable {

    nonisolated static let pages: [ActivityTagDetailContentPage] = [
        .stats, .activities, .marineLife, .buddies, .media,
    ]

    nonisolated static var pageCount: Int { pages.count }

    nonisolated static var defaultPage: ActivityTagDetailContentPage { .stats }

    nonisolated static func accessibilityIdentifier(for page: ActivityTagDetailContentPage) -> String {
        switch page {
        case .stats:
            return "ActivityTagDetails.ContentPager.Stats"
        case .activities:
            return "ActivityTagDetails.ContentPager.Activities"
        case .marineLife:
            return "ActivityTagDetails.ContentPager.MarineLife"
        case .buddies:
            return "ActivityTagDetails.ContentPager.Buddies"
        case .media:
            return "ActivityTagDetails.ContentPager.Media"
        }
    }

    nonisolated static func usesStaticPagerLayout(for page: ActivityTagDetailContentPage) -> Bool {
        switch page {
        case .stats:
            return true
        case .activities, .marineLife, .buddies, .media:
            return false
        }
    }

    nonisolated static func staticPagerContentAlignment(
        for page: ActivityTagDetailContentPage
    ) -> Alignment {
        switch page {
        case .stats:
            return .center
        case .activities, .marineLife, .buddies, .media:
            return .top
        }
    }

    nonisolated static func pagerPageLayout(
        for page: ActivityTagDetailContentPage
    ) -> BlueSheetDetailPagerPageLayout {
        BlueSheetDetailPagerPageLayout(
            usesStaticLayout: usesStaticPagerLayout(for: page),
            staticContentAlignment: staticPagerContentAlignment(for: page),
            scrollBottomInsetExtra: usesStaticPagerLayout(for: page)
                ? 0
                : BlueSheetDetailPagerPresentation.tripScrollBottomInsetExtra,
            accessibilityIdentifier: accessibilityIdentifier(for: page)
        )
    }
}
