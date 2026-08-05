import Foundation

/// Home **`NavigationStack`** destinations (dive detail, media focus, catalog site, field-guide species).
enum HomeRoute: Hashable {
    case profile
    case tripPlanner
    case tripDetail(UUID)
    case tripDetailMedia(tripID: UUID, mediaID: UUID)
    case diveDetail(UUID)
    case diveMedia(diveID: UUID, mediaID: UUID)
    case diveSite(UUID)
    case marineLife(String)
    case diveBuddy(UUID)
    case lifetimeStatsLeaderboard(HomeLifetimeStatsLeaderboardKind)
    /// Home bell → past notifications list.
    case notifications
    /// Notification row → friend profile.
    case friendProfile(GoDiveFriendGraphService.FriendEdge)
    /// Notification row → friend-shared activity detail (row data already loaded by the list).
    case buddySharedActivity(LogbookBuddyFeedPresentation.Row)
    /// Equipment service reminder tap → gear detail.
    case equipmentDetail(UUID)
}
