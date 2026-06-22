import Foundation
#if canImport(Photos)
import Photos
#endif

/// Preloads PhotoKit hero frames and video assets for the Home highlights carousel (session-pinned).
@MainActor
enum HomeMediaHighlightWarmup {

    /// Full-bleed Home hero — container width × **`heroScaleFactor`**, capped at **`maxHeroImageEdge`**.
    nonisolated static var preloadImageEdge: CGFloat {
        HomeMediaHighlightWarmupPresentation.heroImageEdge()
    }

    nonisolated static func shouldStoreInSessionCache(edge: CGFloat) -> Bool {
        edge >= HomeMediaHighlightWarmupPresentation.previewImageEdge - 1
            || edge >= preloadImageEdge - 1
    }

    private static var inflightWarmups: [String: Task<Void, Never>] = [:]
    private static var cachedVideoDurationSeconds: [String: Double] = [:]

    /// Warms all carousel slides at hero quality plus video assets and playback snapshots.
    static func warmHighlights(
        _ highlights: [HomeMediaHighlight],
        mediaByID: [UUID: DiveMediaPhoto]
    ) async {
        let limited = Array(highlights.prefix(HomeMediaHighlightPresentation.carouselLimit))
        guard !limited.isEmpty else { return }

        let mediaRows = limited.compactMap { mediaByID[$0.mediaID] }
        pinCarouselSessionCache(for: limited, mediaByID: mediaByID)
        await warmBootstrapTier(mediaRows)
        await warmCarouselVideoAssets(for: mediaRows)
        await warmCarouselVideoPlaybackSnapshots(for: mediaRows)
        registerHomeCarouselSession(for: mediaRows)
    }

    /// Ensures a carousel video has a warmed **`AVAsset`** and SwiftUI playback snapshot (idempotent).
    static func ensureCarouselVideoReady(for media: DiveMediaPhoto) async {
        #if canImport(Photos) && canImport(AVFoundation)
        guard media.resolvedMediaKind == .video else { return }
        await warmCarouselVideoAsset(for: media)
        await warmCarouselVideoPlaybackSnapshot(for: media)
        #endif
    }

    /// **`true`** when every carousel slide has a poster frame in the session cache.
    static func carouselHighlightsAreDisplayable(
        _ highlights: [HomeMediaHighlight],
        mediaByID: [UUID: DiveMediaPhoto]
    ) -> Bool {
        let limited = Array(highlights.prefix(HomeMediaHighlightPresentation.carouselLimit))
        guard !limited.isEmpty else { return true }
        return limited.allSatisfy { highlight in
            guard let media = mediaByID[highlight.mediaID] else { return false }
            return isHighlightDisplayable(highlight, media: media)
        }
    }

    /// Re-seeds stored previews and re-pins carousel library ids after session cache clears.
    static func repinCarouselSessionCache(
        highlights: [HomeMediaHighlight],
        mediaByID: [UUID: DiveMediaPhoto]
    ) {
        pinCarouselSessionCache(for: highlights, mediaByID: mediaByID)
    }

    private static func pinCarouselSessionCache(
        for highlights: [HomeMediaHighlight],
        mediaByID: [UUID: DiveMediaPhoto]
    ) {
        let identifiers = highlights.compactMap { highlight -> String? in
            mediaByID[highlight.mediaID]?.libraryAssetLocalIdentifier
        }
        HomeMediaHighlightSessionCache.shared.setPinnedCarouselLocalIdentifiers(identifiers)
        DiveMediaVideoAssetSessionCache.shared.setPinnedCarouselLocalIdentifiers(identifiers)
        HomeMediaCarouselDebug.warmupRepinned(
            libraryIdentifiers: identifiers,
            mediaIDs: highlights.map(\.mediaID)
        )
        #if canImport(UIKit)
        let mediaRows = highlights.compactMap { mediaByID[$0.mediaID] }
        DiveMediaPreviewStorage.seedSessionCache(for: mediaRows)
        #endif
    }

    /// **`true`** when the slide can show a poster (video asset may still be loading).
    static func isHighlightDisplayable(_ highlight: HomeMediaHighlight, media: DiveMediaPhoto) -> Bool {
        HomeMediaHighlightSessionCache.shared.hasDisplayableImage(for: media)
    }

    /// Maps owned media rows to carousel sources (includes Photos video duration for eligibility).
    static func highlightSources(from mediaPhotos: [DiveMediaPhoto]) -> [HomeMediaHighlightSource] {
        mediaPhotos.map { photo in
            let kind = photo.resolvedMediaKind
            let duration: Double? = {
                #if canImport(Photos)
                guard kind == .video, let identifier = photo.libraryAssetLocalIdentifier else { return nil }
                return cachedVideoDurationSeconds(localIdentifier: identifier)
                #else
                return nil
                #endif
            }()
            return HomeMediaHighlightSource(
                mediaID: photo.id,
                diveActivityID: photo.diveActivityID,
                mediaKind: kind,
                videoDurationSeconds: duration
            )
        }
    }

    #if canImport(Photos)
    private static func cachedVideoDurationSeconds(localIdentifier: String) -> Double? {
        if let cached = cachedVideoDurationSeconds[localIdentifier] {
            return cached
        }
        let duration = DiveMediaReferenceLoader.videoDurationSeconds(localIdentifier: localIdentifier)
        if let duration {
            cachedVideoDurationSeconds[localIdentifier] = duration
        }
        return duration
    }
    #endif

    // MARK: - Bootstrap warm tiers

    private static func warmBootstrapTier(_ mediaRows: [DiveMediaPhoto]) async {
        guard !mediaRows.isEmpty else { return }

        #if canImport(Photos) && canImport(UIKit)
        preheatPhotoKit(for: mediaRows)

        await withTaskGroup(of: Void.self) { group in
            for media in mediaRows {
                group.addTask {
                    await warmMediaRow(media, quality: .full)
                }
            }
        }
        #endif
    }

    private static func warmCarouselVideoAssets(for mediaRows: [DiveMediaPhoto]) async {
        #if canImport(Photos) && canImport(AVFoundation)
        await withTaskGroup(of: Void.self) { group in
            for media in mediaRows where media.resolvedMediaKind == .video {
                group.addTask {
                    await warmCarouselVideoAsset(for: media)
                }
            }
        }
        #endif
    }

    #if canImport(Photos) && canImport(AVFoundation)
    private static func warmCarouselVideoAsset(for media: DiveMediaPhoto) async {
        guard let identifier = media.libraryAssetLocalIdentifier else { return }
        let quality = DiveMediaVideoRequestQuality.homeCarousel
        if DiveMediaVideoAssetSessionCache.shared.contains(
            localIdentifier: identifier,
            quality: quality
        ) {
            HomeMediaCarouselDebug.warmVideo(
                mediaID: media.id,
                cacheHit: true,
                stored: DiveMediaPreviewStorage.hasStoredPreview(for: media)
            )
            return
        }
        guard let asset = await DiveMediaReferenceLoader.loadVideoAsset(
            localIdentifier: identifier,
            quality: quality
        ) else {
            HomeMediaCarouselDebug.warmVideo(
                mediaID: media.id,
                cacheHit: false,
                stored: DiveMediaPreviewStorage.hasStoredPreview(for: media)
            )
            return
        }
        DiveMediaVideoAssetSessionCache.shared.store(
            asset,
            localIdentifier: identifier,
            quality: quality
        )
        HomeMediaCarouselDebug.warmVideo(
            mediaID: media.id,
            cacheHit: false,
            stored: DiveMediaPreviewStorage.hasStoredPreview(for: media)
        )
    }

    private static func warmCarouselVideoPlaybackSnapshots(for mediaRows: [DiveMediaPhoto]) async {
        await withTaskGroup(of: Void.self) { group in
            for media in mediaRows where media.resolvedMediaKind == .video {
                group.addTask {
                    await warmCarouselVideoPlaybackSnapshot(for: media)
                }
            }
        }
    }

    private static func warmCarouselVideoPlaybackSnapshot(for media: DiveMediaPhoto) async {
        guard let source = media.videoPlaybackSource,
              case .libraryAsset(let identifier) = source else { return }

        if DiveMediaVideoPlaybackSessionCache.shared.swiftUISnapshot(
            forSourceIdentityKey: source.identityKey
        ) != nil {
            return
        }

        guard let playerItem = await DiveMediaReferenceLoader.playerItem(
            localIdentifier: identifier,
            quality: .homeCarousel
        ) else { return }

        let poster = HomeMediaHighlightSessionCache.shared.bestCachedImage(localIdentifier: identifier)
        DiveMediaVideoPlaybackSessionCache.shared.storeSwiftUISnapshot(
            DiveMediaVideoPlaybackSessionCache.SwiftUISnapshot(
                playerItem: playerItem,
                resolvedKey: "\(source.identityKey)|preview",
                videoFidelity: .preview,
                isDisplayReady: false,
                posterImage: poster
            ),
            sourceIdentityKey: source.identityKey
        )
    }

    private static func registerHomeCarouselSession(for mediaRows: [DiveMediaPhoto]) {
        let libraryIdentifiers = mediaRows.compactMap(\.libraryAssetLocalIdentifier)
        let sourceKeys = mediaRows.compactMap { media -> String? in
            guard media.resolvedMediaKind == .video,
                  let identifier = media.libraryAssetLocalIdentifier else { return nil }
            return DiveMediaScopeCachePresentation.libraryAssetSourceIdentityKey(
                localIdentifier: identifier
            )
        }
        DiveMediaScopeCache.shared.activateHomeCarouselSession(
            libraryIdentifiers: libraryIdentifiers,
            sourceIdentityKeys: sourceKeys
        )
    }
    #endif

    private static func warmMediaRow(
        _ media: DiveMediaPhoto,
        quality: HomeMediaHighlightWarmupPresentation.WarmupQuality
    ) async {
        #if canImport(Photos) && canImport(UIKit)
        guard let identifier = media.libraryAssetLocalIdentifier else { return }

        if quality == .full, HomeMediaHighlightSessionCache.shared.isMediaReady(for: media) {
            HomeMediaCarouselDebug.warmImage(
                mediaID: media.id,
                quality: warmupQualityLabel(quality),
                cacheHit: true,
                stored: DiveMediaPreviewStorage.hasStoredPreview(for: media)
            )
            return
        }
        if quality == .preview, HomeMediaHighlightSessionCache.shared.hasDisplayableImage(for: media) {
            HomeMediaCarouselDebug.warmImage(
                mediaID: media.id,
                quality: warmupQualityLabel(quality),
                cacheHit: true,
                stored: DiveMediaPreviewStorage.hasStoredPreview(for: media)
            )
            return
        }

        let inflightKey = "\(identifier)|\(quality)"
        if let existing = inflightWarmups[inflightKey] {
            await existing.value
            return
        }

        let task = Task {
            await performWarmMediaRow(media, identifier: identifier, quality: quality)
        }
        inflightWarmups[inflightKey] = task
        await task.value
        inflightWarmups.removeValue(forKey: inflightKey)
        if media.resolvedMediaKind == .image {
            HomeMediaCarouselDebug.warmImage(
                mediaID: media.id,
                quality: warmupQualityLabel(quality),
                cacheHit: HomeMediaHighlightSessionCache.shared.hasDisplayableImage(for: media),
                stored: DiveMediaPreviewStorage.hasStoredPreview(for: media)
            )
        }
        #endif
    }

    private static func warmupQualityLabel(
        _ quality: HomeMediaHighlightWarmupPresentation.WarmupQuality
    ) -> String {
        switch quality {
        case .preview: "preview"
        case .full: "full"
        }
    }

    #if canImport(Photos) && canImport(UIKit)
    private static func performWarmMediaRow(
        _ media: DiveMediaPhoto,
        identifier: String,
        quality: HomeMediaHighlightWarmupPresentation.WarmupQuality
    ) async {
        if quality == .full, !AppNetworkConnectivitySnapshot.shared.allowsCloudMediaFetch {
            return
        }
        let imageEdge = imageEdge(for: quality)
        let size = CGSize(width: imageEdge, height: imageEdge)

        if HomeMediaHighlightSessionCache.shared.image(for: identifier, edge: imageEdge) == nil {
            if let image = await DiveMediaReferenceLoader.image(
                localIdentifier: identifier,
                targetSize: size,
                deliveryMode: .opportunistic
            ) {
                HomeMediaHighlightSessionCache.shared.storeImage(
                    image,
                    localIdentifier: identifier,
                    edge: imageEdge
                )
            }
        }
    }

    private static func imageEdge(for quality: HomeMediaHighlightWarmupPresentation.WarmupQuality) -> CGFloat {
        switch quality {
        case .preview:
            max(HomeMediaHighlightWarmupPresentation.previewImageEdge, 1)
        case .full:
            max(preloadImageEdge, 1)
        }
    }

    private static func preheatPhotoKit(for mediaRows: [DiveMediaPhoto]) {
        let identifiers = mediaRows
            .prefix(HomeMediaHighlightPresentation.carouselLimit)
            .compactMap(\.libraryAssetLocalIdentifier)
        guard !identifiers.isEmpty else { return }

        let previewEdge = max(HomeMediaHighlightWarmupPresentation.previewImageEdge, 1)
        DiveMediaReferenceLoader.startCachingImages(
            localIdentifiers: Array(identifiers),
            targetSize: CGSize(width: previewEdge, height: previewEdge)
        )
    }
    #endif
}
