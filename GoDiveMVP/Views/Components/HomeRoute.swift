import Foundation

/// Home **`NavigationStack`** destinations (dive detail, media focus, catalog site, field-guide species).
enum HomeRoute: Hashable {
    case diveDetail(UUID)
    case diveMedia(diveID: UUID, mediaID: UUID)
    case diveSite(UUID)
    case marineLife(String)
}
