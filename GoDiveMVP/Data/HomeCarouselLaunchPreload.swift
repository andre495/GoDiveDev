import Foundation
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Pure policy helpers retained for tests / future in-process warm — cross-launch UserDefaults
/// preload was removed so each cold launch can reshuffle the Home carousel.
enum HomeCarouselLaunchPreloadPresentation: Sendable {

    /// One persisted carousel pick — Photos pointer plus kind.
    struct Entry: Codable, Equatable, Sendable {
        let libraryIdentifier: String
        let isVideo: Bool

        nonisolated static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.libraryIdentifier == rhs.libraryIdentifier && lhs.isVideo == rhs.isVideo
        }
    }

    /// Cross-launch preload is disabled: yesterday’s (or earlier today’s) picks must not warm
    /// PhotoKit for a shuffle that will change on this launch.
    nonisolated static func shouldPreloadStoredPicks(
        storedOwnerProfileID: UUID?,
        currentOwnerProfileID: UUID?,
        storedSeed: UInt64?,
        currentSeed: UInt64
    ) -> Bool {
        _ = storedOwnerProfileID
        _ = currentOwnerProfileID
        _ = storedSeed
        _ = currentSeed
        return false
    }

    nonisolated static func entries(
        from picks: [(mediaKind: DiveMediaKind, libraryIdentifier: String?)]
    ) -> [Entry] {
        picks.compactMap { pick in
            guard let identifier = pick.libraryIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !identifier.isEmpty else { return nil }
            return Entry(libraryIdentifier: identifier, isVideo: pick.mediaKind == .video)
        }
    }
}

/// Formerly persisted yesterday’s picks for launch-screen preload. Now a no-op so each
/// cold launch reshuffles; warm still runs after this launch’s picks resolve on Home.
@MainActor
enum HomeCarouselLaunchPreload {

    nonisolated static let userDefaultsKey = "HomeCarouselLaunchPreload.v1"

    static func storeTodaysPicks(
        ownerProfileID: UUID,
        highlights: [HomeMediaHighlight],
        mediaByID: [UUID: DiveMediaPhoto]
    ) {
        _ = ownerProfileID
        _ = highlights
        _ = mediaByID
        // Intentionally empty — do not persist picks across launches.
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    static func preloadStoredPicksIfCurrent(ownerProfileID: UUID?) {
        _ = ownerProfileID
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
