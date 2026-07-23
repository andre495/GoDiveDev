import Foundation

enum LogbookRoute: Hashable {
    /// Full-screen hub: dive / snorkel / connect device.
    case addActivity
    case diveActivityUpload
    case snorkelActivityUpload
    case connectDeviceComingSoon
    case tripPlanner
    case diveDetail(UUID)
    case snorkelDetail(UUID)
    /// Opens snorkel detail with the **Media** tab focused on a specific photo.
    case snorkelMedia(UUID, mediaID: UUID)
    /// Opens the dive detail with the **Media** tab focused on a specific photo at the medium detent.
    case diveMedia(UUID, mediaID: UUID)
    case tripDetail(UUID)
    case tripDetailMedia(tripID: UUID, mediaID: UUID)
    case diveSite(UUID)
    /// Friend-visible dive opened from Activity Log **Buddy Feed**.
    case buddySharedDive(friendUID: String, diveDocumentID: String)
    /// Friend profile from Buddy Feed name tap or post–invite redeem.
    case friendProfile(GoDiveFriendGraphService.FriendEdge)
    /// Buddy / friend profile from unified **Buddies** list (Logbook **Friends** route).
    case buddiesListDetail(BuddiesListNavigationRoute)
    /// Profile **Friends** — opened from Buddy Feed empty state.
    case friends
}

/// Applies a tab-level pending push (e.g. Home **Log Your First Dive** → import sheet).
enum LogbookPendingRouteNavigation: Sendable {
    nonisolated static func path(
        afterConsuming route: LogbookRoute,
        currentPath: [LogbookRoute]
    ) -> [LogbookRoute] {
        switch route {
        case .addActivity:
            return [LogbookRoute.addActivity]
        default:
            var updated = currentPath
            updated.append(route)
            return updated
        }
    }
}
