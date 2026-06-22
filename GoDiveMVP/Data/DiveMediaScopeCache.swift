import Foundation

/// Page- and session-scoped media retention — coordinates when loaded assets stay warm vs. release.
///
/// - **Home carousel** (3 items): pinned for the app session; not subject to page on-demand eviction.
/// - **Dive overview / trip detail / field guide**: progressive load on appear; retain through tab and
///   in-page media changes; release high-fidelity tiers when the page is popped.
enum DiveMediaRetentionScope: Hashable, Sendable {
    case homeCarousel
    case diveOverview(UUID)
    case tripDetail(UUID)
    /// **Field Guide** species detail — tagged photos carousel.
    case marineLifeSpecies(String)
    /// **Explore** dive-site detail — tagged photos carousel.
    case diveSite(UUID)
    /// **Buddy roster** detail — tagged photos carousel.
    case buddyDetail(UUID)
}

/// Warmth tier retained while a page scope is active.
enum DiveMediaRetainedTier: Sendable, Equatable {
    case preview
    case full
}

enum DiveMediaScopeCachePresentation: Sendable {

    nonisolated static func mergedTier(
        existing: DiveMediaRetainedTier?,
        incoming: DiveMediaRetainedTier
    ) -> DiveMediaRetainedTier {
        switch (existing, incoming) {
        case (.full, _), (_, .full):
            return .full
        case (.preview, .preview), (nil, .preview):
            return .preview
        }
    }

    nonisolated static func libraryAssetSourceIdentityKey(localIdentifier: String) -> String {
        "asset:\(localIdentifier)"
    }
}

/// App-wide coordinator for scoped media retention (loading/caching only — no UI).
@MainActor
final class DiveMediaScopeCache {
    static let shared = DiveMediaScopeCache()

    private(set) var homeCarouselSourceIdentityKeys: Set<String> = []
    private var activeScopes: Set<DiveMediaRetentionScope> = []
    private var retainedByScope: [DiveMediaRetentionScope: [String: DiveMediaRetainedTier]] = [:]

    private init() {}

    func activateHomeCarouselSession(
        libraryIdentifiers: [String],
        sourceIdentityKeys: [String]
    ) {
        homeCarouselSourceIdentityKeys = Set(sourceIdentityKeys)
        activeScopes.insert(.homeCarousel)
        DiveMediaVideoPlaybackSessionCache.shared.setPinnedSourceIdentityKeys(homeCarouselSourceIdentityKeys)
    }

    func activateScope(_ scope: DiveMediaRetentionScope) {
        guard scope != .homeCarousel else { return }
        activeScopes.insert(scope)
    }

    func deactivateScope(_ scope: DiveMediaRetentionScope) {
        guard scope != .homeCarousel else { return }
        activeScopes.remove(scope)
        releaseHighFidelityMedia(for: scope)
        retainedByScope.removeValue(forKey: scope)
    }

    func noteMediaLoaded(
        libraryIdentifier: String,
        tier: DiveMediaRetainedTier
    ) {
        guard let scope = activePageScope else { return }
        var map = retainedByScope[scope, default: [:]]
        map[libraryIdentifier] = DiveMediaScopeCachePresentation.mergedTier(
            existing: map[libraryIdentifier],
            incoming: tier
        )
        retainedByScope[scope] = map

        if tier == .full {
            DiveMediaVideoAssetSessionCache.shared.retainFullQuality(
                localIdentifier: libraryIdentifier,
                scope: scope
            )
        }
    }

    /// Drops non-carousel session caches on background while keeping Home carousel picks warm.
    func clearSessionCachesOnBackground() {
        for scope in activeScopes where scope != .homeCarousel {
            releaseHighFidelityMedia(for: scope)
        }
        retainedByScope = retainedByScope.filter { $0.key == .homeCarousel }

        HomeMediaHighlightSessionCache.shared.clearUnpinned()
        DiveMediaVideoAssetSessionCache.shared.clearUnpinned()
        DiveMediaVideoPlaybackSessionCache.shared.clearUnpinnedExcept(
            homeCarouselSourceIdentityKeys
        )
        DiveMediaReferenceLoader.clearInflightImageLoads()
    }

    private var activePageScope: DiveMediaRetentionScope? {
        activeScopes.first { scope in
            switch scope {
            case .homeCarousel:
                return false
            case .diveOverview, .tripDetail, .marineLifeSpecies, .diveSite, .buddyDetail:
                return true
            }
        }
    }

    private func releaseHighFidelityMedia(for scope: DiveMediaRetentionScope) {
        guard let entries = retainedByScope[scope] else { return }

        for (libraryIdentifier, tier) in entries {
            if tier == .full {
                DiveMediaVideoAssetSessionCache.shared.releaseFullQuality(
                    localIdentifier: libraryIdentifier,
                    scope: scope
                )
            }
            DiveMediaVideoAssetSessionCache.shared.releasePreviewQuality(
                localIdentifier: libraryIdentifier
            )
            let sourceKey = DiveMediaScopeCachePresentation.libraryAssetSourceIdentityKey(
                localIdentifier: libraryIdentifier
            )
            if !homeCarouselSourceIdentityKeys.contains(sourceKey) {
                DiveMediaVideoPlaybackSessionCache.shared.invalidateLibraryPlayback(
                    sourceIdentityKey: sourceKey
                )
            }
            HomeMediaHighlightSessionCache.shared.releaseImages(
                localIdentifier: libraryIdentifier
            )
            DiveMediaReferenceLoader.releaseCachedImages(forLocalIdentifier: libraryIdentifier)
        }
    }
}
