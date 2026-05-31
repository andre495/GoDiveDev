import Foundation
import SwiftData
#if canImport(Photos)
import Photos
#endif

/// Preloads PhotoKit hero frames and shareable video **`AVAsset`**s for the Home highlights carousel.
@MainActor
enum HomeMediaHighlightWarmup {

    /// Full-bleed Home hero — ~390 pt width at ~3× scale.
    nonisolated static let preloadImageEdge: CGFloat = 1_200

    nonisolated static func shouldStoreInSessionCache(edge: CGFloat) -> Bool {
        edge >= HomeMediaHighlightWarmupPresentation.previewImageEdge - 1
            || edge >= preloadImageEdge - 1
    }

    private static var inflightWarmups: [String: Task<Void, Never>] = [:]
    private static var backgroundFullWarmupTask: Task<Void, Never>?

    /// Warms carousel picks — previews first, then upgrades all to full quality in the background.
    static func warmHighlights(
        _ highlights: [HomeMediaHighlight],
        mediaByID: [UUID: DiveMediaPhoto]
    ) async {
        let limited = Array(highlights.prefix(HomeMediaHighlightPresentation.carouselLimit))
        guard !limited.isEmpty else { return }

        let mediaRows = limited.compactMap { mediaByID[$0.mediaID] }
        await warmBootstrapTier(mediaRows)
        scheduleBackgroundFullQualityWarmup(for: mediaRows)
    }

    /// Bootstrap: full quality for the first picks, preview-only for the rest; then background full upgrade.
    static func warmFromStore(modelContext: ModelContext, ownerProfileID: UUID) async {
        let bundle = highlightsFromStore(
            modelContext: modelContext,
            ownerProfileID: ownerProfileID
        )
        guard !bundle.highlights.isEmpty else { return }

        let limited = Array(bundle.highlights.prefix(HomeMediaHighlightPresentation.carouselLimit))
        let mediaRows = limited.compactMap { bundle.mediaByID[$0.mediaID] }
        await warmBootstrapTier(mediaRows)
        scheduleBackgroundFullQualityWarmup(for: mediaRows)
    }

    /// **`true`** when the first carousel item is fully warmed (hero + video asset when applicable).
    static func isHighlightReady(_ highlight: HomeMediaHighlight, media: DiveMediaPhoto) -> Bool {
        HomeMediaHighlightSessionCache.shared.isMediaReady(for: media)
    }

    /// **`true`** when bootstrap tiers are satisfied for every carousel pick.
    static func isBootstrapReady(
        highlights: [HomeMediaHighlight],
        mediaByID: [UUID: DiveMediaPhoto]
    ) -> Bool {
        let limited = Array(highlights.prefix(HomeMediaHighlightPresentation.carouselLimit))
        guard !limited.isEmpty else { return true }

        var fullReadyCount = 0
        var previewOrFullReadyCount = 0

        for (index, highlight) in limited.enumerated() {
            guard let media = mediaByID[highlight.mediaID] else { return false }
            let hasPreview = HomeMediaHighlightSessionCache.shared.hasDisplayableImage(for: media)
            guard hasPreview else { return false }
            previewOrFullReadyCount += 1

            if index < HomeMediaHighlightWarmupPresentation.startupFullQualityCount,
               HomeMediaHighlightSessionCache.shared.isMediaReady(for: media) {
                fullReadyCount += 1
            }
        }

        return HomeMediaHighlightWarmupPresentation.isBootstrapReady(
            fullReadyCount: fullReadyCount,
            previewOrFullReadyCount: previewOrFullReadyCount,
            totalCount: limited.count
        )
    }

    // MARK: - Bootstrap + background tiers

    private static func warmBootstrapTier(_ mediaRows: [DiveMediaPhoto]) async {
        guard !mediaRows.isEmpty else { return }

        #if canImport(Photos) && canImport(UIKit)
        preheatPhotoKit(for: mediaRows)

        let fullRows = Array(mediaRows.prefix(HomeMediaHighlightWarmupPresentation.startupFullQualityCount))
        for media in fullRows {
            await warmMediaRow(media, quality: .full)
        }

        let previewRows = Array(mediaRows.dropFirst(HomeMediaHighlightWarmupPresentation.startupFullQualityCount))
        await withTaskGroup(of: Void.self) { group in
            for media in previewRows {
                group.addTask {
                    await warmMediaRow(media, quality: .preview)
                }
            }
        }
        #endif
    }

    private static func scheduleBackgroundFullQualityWarmup(for mediaRows: [DiveMediaPhoto]) {
        backgroundFullWarmupTask?.cancel()
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
        let imageEdge = imageEdge(for: quality)
        let size = CGSize(width: imageEdge, height: imageEdge)

        if HomeMediaHighlightSessionCache.shared.image(for: identifier, edge: imageEdge) == nil {
            if let image = await DiveMediaReferenceLoader.image(
                localIdentifier: identifier,
                targetSize: size
            ) {
                HomeMediaHighlightSessionCache.shared.storeImage(
                    image,
                    localIdentifier: identifier,
                    edge: imageEdge
                )
            }
        }

        guard quality == .full,
              media.resolvedMediaKind == .video,
              !HomeMediaHighlightSessionCache.shared.containsVideoAsset(localIdentifier: identifier),
              let avAsset = await DiveMediaReferenceLoader.loadVideoAsset(localIdentifier: identifier) else {
            return
        }
        HomeMediaHighlightSessionCache.shared.storeVideoAsset(
            avAsset,
            localIdentifier: identifier
        )
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
        let identifiers = mediaRows.compactMap(\.libraryAssetLocalIdentifier)
        guard !identifiers.isEmpty else { return }

        let previewEdge = max(HomeMediaHighlightWarmupPresentation.previewImageEdge, 1)
        DiveMediaReferenceLoader.startCachingImages(
            localIdentifiers: identifiers,
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
        let mediaSources = mediaPhotos.map {
            HomeMediaHighlightSource(mediaID: $0.id, diveActivityID: $0.diveActivityID)
        }
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
