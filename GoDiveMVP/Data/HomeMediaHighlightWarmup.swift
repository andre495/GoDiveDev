import Foundation
import SwiftData
#if canImport(Photos)
import Photos
#endif

/// Preloads PhotoKit hero frames for the Home highlights carousel (video loads on the active slide only).
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
    private static var backgroundFullWarmupTask: Task<Void, Never>?
    private static var cachedVideoDurationSeconds: [String: Double] = [:]

    /// Warms slide **0** at hero quality and all other slides at preview immediately (no startup delay).
    static func warmHighlights(
        _ highlights: [HomeMediaHighlight],
        mediaByID: [UUID: DiveMediaPhoto]
    ) async {
        let limited = Array(highlights.prefix(HomeMediaHighlightPresentation.carouselLimit))
        guard !limited.isEmpty else { return }

        let mediaRows = limited.compactMap { mediaByID[$0.mediaID] }
        pinCarouselSessionCache(for: limited, mediaByID: mediaByID)
        await warmBootstrapTier(mediaRows)
        await warmPreviewTier(for: Array(mediaRows.dropFirst()))
        scheduleBackgroundFullQualityWarmup(for: mediaRows)
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

    private static func pinCarouselSessionCache(
        for highlights: [HomeMediaHighlight],
        mediaByID: [UUID: DiveMediaPhoto]
    ) {
        let identifiers = highlights.compactMap { highlight -> String? in
            mediaByID[highlight.mediaID]?.libraryAssetLocalIdentifier
        }
        HomeMediaHighlightSessionCache.shared.setPinnedCarouselLocalIdentifiers(identifiers)
    }

    /// Warms carousel picks from SwiftData, returning once bootstrap tiers are satisfied; remaining warm work continues in the background.
    static func warmFromStore(modelContext: ModelContext, ownerProfileID: UUID) async {
        let bundle = highlightsFromStore(
            modelContext: modelContext,
            ownerProfileID: ownerProfileID
        )
        guard !bundle.highlights.isEmpty else { return }

        let limited = Array(bundle.highlights.prefix(HomeMediaHighlightPresentation.carouselLimit))
        let mediaRows = limited.compactMap { bundle.mediaByID[$0.mediaID] }
        startBackgroundWarmup(mediaRows: mediaRows)
        await waitForOverlayDismiss(
            highlights: limited,
            mediaByID: bundle.mediaByID
        )
    }

    /// **`true`** when the first carousel item is fully warmed (hero + video asset when applicable).
    static func isHighlightReady(_ highlight: HomeMediaHighlight, media: DiveMediaPhoto) -> Bool {
        HomeMediaHighlightSessionCache.shared.isMediaReady(for: media)
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

    /// **`true`** when slide **0** has a full hero poster.
    static func isBootstrapReady(
        highlights: [HomeMediaHighlight],
        mediaByID: [UUID: DiveMediaPhoto]
    ) -> Bool {
        let limited = Array(highlights.prefix(HomeMediaHighlightPresentation.carouselLimit))
        guard let first = limited.first,
              let media = mediaByID[first.mediaID] else {
            return limited.isEmpty
        }

        let fullReadyCount = hasHeroPoster(for: media) ? 1 : 0
        let previewOrFullReadyCount = HomeMediaHighlightSessionCache.shared.hasDisplayableImage(for: media) ? 1 : 0
        return HomeMediaHighlightWarmupPresentation.isBootstrapReady(
            fullReadyCount: fullReadyCount,
            previewOrFullReadyCount: previewOrFullReadyCount,
            totalCount: limited.count
        )
    }

    /// **`true`** when the launch overlay can dismiss (bootstrap complete, first poster ready, or timeout in **`waitForOverlayDismiss`**).
    static func isOverlayDismissReady(
        highlights: [HomeMediaHighlight],
        mediaByID: [UUID: DiveMediaPhoto]
    ) -> Bool {
        let limited = Array(highlights.prefix(HomeMediaHighlightPresentation.carouselLimit))
        guard !limited.isEmpty else { return true }

        let bootstrapReady = isBootstrapReady(highlights: limited, mediaByID: mediaByID)
        let firstDisplayable: Bool = {
            guard let first = limited.first,
                  let media = mediaByID[first.mediaID] else { return false }
            return isHighlightDisplayable(first, media: media)
        }()
        return HomeMediaHighlightWarmupPresentation.isOverlayDismissReady(
            isBootstrapReady: bootstrapReady,
            firstSlideHasDisplayableImage: firstDisplayable
        )
    }

    private static func hasHeroPoster(for media: DiveMediaPhoto) -> Bool {
        guard let identifier = media.libraryAssetLocalIdentifier else { return false }
        return HomeMediaHighlightSessionCache.shared.containsImage(
            localIdentifier: identifier,
            edge: preloadImageEdge
        )
    }

    // MARK: - Bootstrap + background tiers

    private static let overlayDismissPollIntervalNanoseconds: UInt64 = 50_000_000

    private static var overlayDismissMaxWaitNanoseconds: UInt64 {
        UInt64(HomeMediaHighlightWarmupPresentation.bootstrapOverlayMaxWaitSeconds * 1_000_000_000)
    }

    private static func startBackgroundWarmup(mediaRows: [DiveMediaPhoto]) {
        Task {
            await warmBootstrapTier(mediaRows)
            scheduleDeferredCarouselWarmup(for: mediaRows)
        }
    }

    private static func waitForOverlayDismiss(
        highlights: [HomeMediaHighlight],
        mediaByID: [UUID: DiveMediaPhoto]
    ) async {
        let deadline = DispatchTime.now().uptimeNanoseconds + overlayDismissMaxWaitNanoseconds
        while !isOverlayDismissReady(highlights: highlights, mediaByID: mediaByID) {
            if DispatchTime.now().uptimeNanoseconds >= deadline { break }
            try? await Task.sleep(nanoseconds: overlayDismissPollIntervalNanoseconds)
        }
    }

    private static func warmBootstrapTier(_ mediaRows: [DiveMediaPhoto]) async {
        guard let first = mediaRows.first else { return }

        #if canImport(Photos) && canImport(UIKit)
        preheatPhotoKit(for: [first])

        await warmMediaRow(first, quality: .full)
        #endif
    }

    private static func warmPreviewTier(for mediaRows: [DiveMediaPhoto]) async {
        guard !mediaRows.isEmpty else { return }
        #if canImport(Photos) && canImport(UIKit)
        await withTaskGroup(of: Void.self) { group in
            for media in mediaRows {
                group.addTask {
                    await warmMediaRow(media, quality: .preview)
                }
            }
        }
        #endif
    }

    private static func scheduleDeferredCarouselWarmup(for mediaRows: [DiveMediaPhoto]) {
        backgroundFullWarmupTask?.cancel()
        let remainder = Array(mediaRows.dropFirst())
        guard !remainder.isEmpty else { return }

        backgroundFullWarmupTask = Task {
            let delay = HomeMediaHighlightWarmupPresentation.deferredCarouselWarmDelaySeconds
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }

            await withTaskGroup(of: Void.self) { group in
                for media in remainder {
                    group.addTask {
                        await warmMediaRow(media, quality: .preview)
                    }
                }
            }
            guard !Task.isCancelled else { return }
            scheduleBackgroundFullQualityWarmup(for: mediaRows)
        }
    }

    private static func scheduleBackgroundFullQualityWarmup(for mediaRows: [DiveMediaPhoto]) {
        backgroundFullWarmupTask?.cancel()
        guard AppNetworkConnectivitySnapshot.shared.allowsCloudMediaFetch else { return }
        let remainder = Array(mediaRows.dropFirst(HomeMediaHighlightWarmupPresentation.startupFullQualityCount))
        guard !remainder.isEmpty else { return }

        backgroundFullWarmupTask = Task {
            await withTaskGroup(of: Void.self) { group in
                for media in remainder {
                    group.addTask {
                        await warmMediaRow(media, quality: .full)
                    }
                }
            }
        }
    }

    private static func warmMediaRow(
        _ media: DiveMediaPhoto,
        quality: HomeMediaHighlightWarmupPresentation.WarmupQuality
    ) async {
        #if canImport(Photos) && canImport(UIKit)
        guard let identifier = media.libraryAssetLocalIdentifier else { return }

        if quality == .full, HomeMediaHighlightSessionCache.shared.isMediaReady(for: media) {
            return
        }
        if quality == .preview, HomeMediaHighlightSessionCache.shared.hasDisplayableImage(for: media) {
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
        #endif
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
        let identifiers = mediaRows.prefix(1).compactMap(\.libraryAssetLocalIdentifier)
        guard !identifiers.isEmpty else { return }

        let previewEdge = max(HomeMediaHighlightWarmupPresentation.previewImageEdge, 1)
        DiveMediaReferenceLoader.startCachingImages(
            localIdentifiers: Array(identifiers),
            targetSize: CGSize(width: previewEdge, height: previewEdge)
        )
    }
    #endif

    private struct StoreHighlights {
        let highlights: [HomeMediaHighlight]
        let mediaByID: [UUID: DiveMediaPhoto]
    }

    private static func highlightsFromStore(
        modelContext: ModelContext,
        ownerProfileID: UUID
    ) -> StoreHighlights {
        let dives = fetchOwnerDives(modelContext: modelContext, ownerProfileID: ownerProfileID)
        guard !dives.isEmpty else {
            return StoreHighlights(highlights: [], mediaByID: [:])
        }

        let ownerDiveIDs = Set(dives.map(\.id))
        let mediaPhotos = fetchOwnerMedia(modelContext: modelContext, ownerDiveIDs: ownerDiveIDs)
        guard !mediaPhotos.isEmpty else {
            return StoreHighlights(highlights: [], mediaByID: [:])
        }

        let diveInputs = dives.map { activity in
            let useChronologicalNumbers = AppUserSettings.automaticallyRenumberDives
            let chronologicalNumbers = useChronologicalNumbers
                ? DiveActivityDiveNumbering.numberedDiveSequentialIndicesById(for: dives)
                : [:]
            return HomeDiveStatsInput(
                id: activity.id,
                maxDepthMeters: activity.maxDepthMeters,
                durationMinutes: activity.durationMinutes,
                diveSiteID: activity.diveSiteID,
                diveNumberLabel: HomeMediaHighlightPresentation.diveNumberLabel(
                    diveNumber: activity.diveNumber,
                    diveNumberExplicitlyNone: activity.diveNumberExplicitlyNone,
                    chronologicalIndex: chronologicalNumbers[activity.id],
                    useChronologicalNumbers: useChronologicalNumbers
                ),
                siteDisplayName: LogbookActivityRow.displayName(for: activity)
            )
        }
        let mediaSources = highlightSources(from: mediaPhotos)
        let sightingInputs = highlightSightingInputs(
            modelContext: modelContext,
            ownerDiveIDs: ownerDiveIDs
        )
        let taggedSpeciesCountByMediaID = HomeMediaHighlightPresentation.taggedSpeciesCountByMediaID(
            sightings: sightingInputs,
            ownerDiveIDs: ownerDiveIDs
        )
        let candidates = HomeMediaHighlightPresentation.buildCandidates(
            mediaPhotos: mediaSources,
            dives: diveInputs,
            taggedSpeciesCountByMediaID: taggedSpeciesCountByMediaID
        )
        let highlights = HomeMediaHighlightPresentation.highlightsForOwner(
            ownerProfileID: ownerProfileID,
            candidates: candidates
        )
        let mediaByID = Dictionary(uniqueKeysWithValues: mediaPhotos.map { ($0.id, $0) })
        return StoreHighlights(highlights: highlights, mediaByID: mediaByID)
    }

    private static func fetchOwnerDives(
        modelContext: ModelContext,
        ownerProfileID: UUID
    ) -> [DiveActivity] {
        let descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate { $0.ownerProfileID == ownerProfileID },
            sortBy: [
                SortDescriptor(\.startTime, order: .reverse),
                SortDescriptor(\.id, order: .forward),
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private static func fetchOwnerMedia(
        modelContext: ModelContext,
        ownerDiveIDs: Set<UUID>
    ) -> [DiveMediaPhoto] {
        guard !ownerDiveIDs.isEmpty else { return [] }
        let descriptor = FetchDescriptor<DiveMediaPhoto>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { photo in
            guard let diveID = photo.diveActivityID else { return false }
            return ownerDiveIDs.contains(diveID)
        }
    }

    private static func highlightSightingInputs(
        modelContext: ModelContext,
        ownerDiveIDs: Set<UUID>
    ) -> [HomeMediaHighlightSightingInput] {
        let sightingDescriptor = FetchDescriptor<SightingInstance>()
        let sightings = (try? modelContext.fetch(sightingDescriptor)) ?? []
        return sightings.map {
            HomeMediaHighlightSightingInput(
                mediaPhotoID: $0.mediaPhotoID,
                diveActivityID: $0.diveActivityID
            )
        }
    }
}
