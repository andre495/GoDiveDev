import Foundation

enum LogbookRoute: Hashable {
    case addActivity
    case tripPlanner
    case diveDetail(UUID)
    /// Opens the dive detail with the **Media** tab focused on a specific photo at the medium detent.
    case diveMedia(UUID, mediaID: UUID)
    case tripDetail(UUID)
    case tripDetailMedia(tripID: UUID, mediaID: UUID)
    case diveSite(UUID)
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
