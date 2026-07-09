import Foundation
import SwiftData

/// Home-aligned hero + sheet seam inputs for pushed buddy/trip pages.
enum HomeOverviewPushedLayoutPresentation {

    /// Same stats-band + leaderboard visibility **`LogOverviewView.homeOverviewLayoutMetrics`** uses.
    @MainActor
    static func statsPanelContentHeightMatchingHome(
        activities: [DiveActivity],
        diveBuddyTags: [DiveBuddyTag] = [],
        excludingBuddyID: UUID? = nil
    ) -> CGFloat {
        seamInputs(
            activities: activities,
            diveBuddyTags: diveBuddyTags,
            excludingBuddyID: excludingBuddyID
        ).statsPanelContentHeight
    }

    /// Leaderboard visibility + stats band for hero seam / **`screenBot`** alignment with Home.
    @MainActor
    static func seamInputs(
        activities: [DiveActivity],
        diveBuddyTags: [DiveBuddyTag] = [],
        excludingBuddyID: UUID? = nil
    ) -> SeamInputs {
        let ownerDiveIDs = Set(activities.map(\.id))
        let tagsFromDiveBuddyTags = HomeBuddyLeaderboardSeeding.tagInputs(
            from: diveBuddyTags,
            ownerDiveIDs: ownerDiveIDs
        )
        let tagsFromActivities = HomeBuddyLeaderboardSeeding.tagInputs(from: activities)
        let tags = HomeBuddyLeaderboardSeeding.mergedTagInputs(
            tagsFromDiveBuddyTags,
            tagsFromActivities
        )
        if let anchored = HomeOverviewLayoutAnchor.matchingRootSeamInputs() {
            return SeamInputs(
                statsPanelContentHeight: anchored.statsPanelContentHeight,
                showsBuddyLeaderboard: anchored.showsBuddyLeaderboard
            )
        }
        let entries = HomeBuddyLeaderboardPresentation.topEntries(
            from: tags,
            excludingBuddyID: excludingBuddyID
        )
        let showsBuddyLeaderboard = HomeBuddyLeaderboardPresentation.shouldShow(
            diveCount: activities.count,
            entries: entries
        )
        return SeamInputs(
            statsPanelContentHeight: HomeLifetimeStatsLayout.estimatedPanelContentHeight(
                showsBuddyLeaderboard: showsBuddyLeaderboard
            ),
            showsBuddyLeaderboard: showsBuddyLeaderboard
        )
    }

    struct SeamInputs: Sendable, Equatable {
        let statsPanelContentHeight: CGFloat
        let showsBuddyLeaderboard: Bool
    }

    /// Pushed buddy/trip hero seam without scanning the full logbook — uses Home anchor or default lifetime grid + **Top buddies** band.
    @MainActor
    static func pushedPageSeamInputs() -> SeamInputs {
        if let anchored = HomeOverviewLayoutAnchor.matchingRootSeamInputs() {
            return SeamInputs(
                statsPanelContentHeight: anchored.statsPanelContentHeight,
                showsBuddyLeaderboard: anchored.showsBuddyLeaderboard
            )
        }
        return HomeTabRootLayoutPresentation.defaultLifetimeGridSeamInputs
    }
}
