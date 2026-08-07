import Foundation
import SwiftUI

/// Horizontal pager pages on **`FriendProfileView`** (below the identity row).
enum FriendProfileContentPage: Hashable, Sendable, Identifiable {
    case diverStats
    case sharedActivities
    case sharedMedia

    var id: Self { self }
}

enum FriendProfileActivityListFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case together

    var id: Self { self }

    var title: String {
        switch self {
        case .all: return "All"
        case .together: return "Together"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "list.bullet"
        case .together: return "person.2.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .all: return "All shared activities"
        case .together: return "Activities together"
        }
    }
}

enum FriendProfileContentPagerPresentation: Sendable {
    nonisolated static let pages: [FriendProfileContentPage] = [
        .diverStats,
        .sharedActivities,
        .sharedMedia,
    ]

    nonisolated static var defaultPage: FriendProfileContentPage { .diverStats }

    nonisolated static let diverStatsPageTitle = ProfileDetailContentPagerPresentation.diverStatsPageTitle
    nonisolated static let sharedActivitiesPageTitle = "Activities"
    nonisolated static let sharedMediaPageTitle = "Shared media"

    nonisolated static let showsBuddyLeaderboardOnDiverStats = false
    nonisolated static let showsLifetimeSummaryOnDiverStats = false
    nonisolated static let opensLeaderboardsOnDiverStats = false

    nonisolated static let activityFilterAccessibilityIdentifier = "FriendProfile.ActivityFilter"
    nonisolated static let sharedMediaEmptyMessage = "No photos or videos shared yet."

    nonisolated static func pageTitle(for page: FriendProfileContentPage) -> String {
        switch page {
        case .diverStats:
            return diverStatsPageTitle
        case .sharedActivities:
            return sharedActivitiesPageTitle
        case .sharedMedia:
            return sharedMediaPageTitle
        }
    }

    nonisolated static func accessibilityIdentifier(for page: FriendProfileContentPage) -> String {
        switch page {
        case .diverStats:
            return "FriendProfile.ContentPager.DiverStats"
        case .sharedActivities:
            return "FriendProfile.ContentPager.SharedActivities"
        case .sharedMedia:
            return "FriendProfile.ContentPager.SharedMedia"
        }
    }

    nonisolated static func usesStaticPagerLayout(for page: FriendProfileContentPage) -> Bool {
        switch page {
        case .diverStats:
            return true
        case .sharedActivities, .sharedMedia:
            return false
        }
    }

    nonisolated static func pagerPageLayout(for page: FriendProfileContentPage) -> BlueSheetDetailPagerPageLayout {
        BlueSheetDetailPagerPageLayout(
            usesStaticLayout: usesStaticPagerLayout(for: page),
            staticContentAlignment: .top,
            accessibilityLabel: pageTitle(for: page),
            accessibilityIdentifier: accessibilityIdentifier(for: page)
        )
    }
}
