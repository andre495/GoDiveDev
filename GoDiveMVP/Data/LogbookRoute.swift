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
