import AVFoundation
import Foundation
#if canImport(Photos)
import Photos
#endif

/// Policy for the simplified Home featured-video path (no local file copy).
enum HomeCarouselVideoPresentation: Sendable {
    /// Soft timeout for a single PhotoKit **`requestPlayerItem`** attempt (retries follow on failure).
    nonisolated static let requestTimeoutSeconds: Double = 20

    /// How many PhotoKit attempts before giving up on a carousel video.
    nonisolated static let maxRequestAttempts: Int = 3

    /// Backoff between failed carousel video attempts.
    nonisolated static let retryBackoffNanoseconds: UInt64 = 750_000_000

    nonisolated static func shouldPreloadLibraryIdentifier(
        mediaKind: DiveMediaKind,
        localIdentifier: String?
    ) -> Bool {
        mediaKind == .video
            && !(localIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    nonisolated static func libraryIdentifiersForPreload(
        from mediaRows: [DiveMediaPhoto],
        limit: Int = HomeMediaHighlightPresentation.carouselLimit
    ) -> [String] {
        Array(
            mediaRows
                .filter { shouldPreloadLibraryIdentifier(mediaKind: $0.resolvedMediaKind, localIdentifier: $0.libraryAssetLocalIdentifier) }
                .compactMap(\.libraryAssetLocalIdentifier)
                .prefix(limit)
        )
    }
}

#if canImport(Photos) && canImport(AVFoundation)
/// Session cache of muted **`AVPlayer`**s for the Home carousel (max **3** library videos).
///
/// Uses PhotoKit **`requestPlayerItem`** only — keeps Photos' streaming item (never copies bytes into the app,
/// never reads **`playerItem.asset`** in the PhotoKit callback).
@MainActor
final class HomeCarouselVideoSessionCache {
    static let shared = HomeCarouselVideoSessionCache()

    private var playersByLibraryID: [String: AVPlayer] = [:]
    private var inflightByLibraryID: [String: Task<AVPlayer?, Never>] = [:]
    private var generation = 0

    private init() {}

    func player(forLibraryIdentifier localIdentifier: String) -> AVPlayer? {
        let key = normalized(localIdentifier)
        guard !key.isEmpty else { return nil }
        return playersByLibraryID[key]
    }

    /// Preloads carousel videos **in caller order** (priority / first slide first), serialized through
    /// the PhotoKit video gate so parallel iCloud streams do not starve slide **0**.
    func preload(libraryIdentifiers: [String]) async {
        var seen = Set<String>()
        var ordered: [String] = []
        for raw in libraryIdentifiers {
            let key = normalized(raw)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            ordered.append(key)
            if ordered.count >= HomeMediaHighlightPresentation.carouselLimit { break }
        }
        guard !ordered.isEmpty else { return }

        for id in ordered {
            _ = await ensurePlayer(forLibraryIdentifier: id)
        }
    }

    func ensurePlayer(forLibraryIdentifier localIdentifier: String) async -> AVPlayer? {
        let key = normalized(localIdentifier)
        guard !key.isEmpty else { return nil }
        if let existing = playersByLibraryID[key] {
            return existing
        }
        if let inflight = inflightByLibraryID[key] {
            return await inflight.value
        }

        let capturedGeneration = generation
        let task = Task<AVPlayer?, Never> { @MainActor in
            let started = Date()
            var player: AVPlayer?
            for attempt in 1 ... HomeCarouselVideoPresentation.maxRequestAttempts {
                player = await DiveMediaVideoPhotoKitGate.withExclusiveAccess {
                    await Self.requestMutedPlayer(localIdentifier: key)
                }
                if player != nil { break }
                if attempt < HomeCarouselVideoPresentation.maxRequestAttempts {
                    try? await Task.sleep(
                        nanoseconds: HomeCarouselVideoPresentation.retryBackoffNanoseconds
                    )
                }
            }
            guard capturedGeneration == self.generation else { return nil }
            if let player {
                self.playersByLibraryID[key] = player
                HomeMediaCarouselDebug.videoAssetRequestSucceeded(
                    localIdentifier: key,
                    quality: "homeSimple",
                    elapsedSeconds: Date().timeIntervalSince(started)
                )
            }
            return player
        }
        inflightByLibraryID[key] = task
        let result = await task.value
        inflightByLibraryID[key] = nil
        return result
    }

    func clear() {
        generation += 1
        for task in inflightByLibraryID.values {
            task.cancel()
        }
        inflightByLibraryID.removeAll()
        for player in playersByLibraryID.values {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        playersByLibraryID.removeAll()
    }

    /// PhotoKit delivered a streaming item after our soft timeout — stash it so the carousel can play.
    func storeLateArrivingPlayerItem(_ item: AVPlayerItem, localIdentifier: String) {
        let key = normalized(localIdentifier)
        guard !key.isEmpty, playersByLibraryID[key] == nil else { return }
        DiveMutedVideoAudioSession.activateForMutedPlayback()
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        playersByLibraryID[key] = player
        HomeMediaCarouselDebug.videoAssetRequestSucceeded(
            localIdentifier: key,
            quality: "homeSimpleLate",
            elapsedSeconds: 0
        )
    }

    private func normalized(_ localIdentifier: String) -> String {
        localIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func requestMutedPlayer(localIdentifier: String) async -> AVPlayer? {
        let trimmed = localIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [trimmed], options: nil)
        guard let phAsset = assets.firstObject, phAsset.mediaType == .video else { return nil }

        let options = PHVideoRequestOptions()
        let networkAllowed = AppNetworkConnectivitySnapshot.shared.allowsCloudMediaFetch
        options.isNetworkAccessAllowed = networkAllowed
        // Medium rendition streams for iCloud-remote originals; `.automatic` forced a full download.
        options.deliveryMode = .mediumQualityFormat

        let progressState = HomeCarouselVideoProgressState()
        options.progressHandler = { progress, error, _, _ in
            progressState.noteProgress(progress)
            Task { @MainActor in
                HomeMediaCarouselDebug.videoLoadProgress(
                    localIdentifier: trimmed,
                    progress: progress,
                    errorDescription: (error as NSError?)?.localizedDescription
                )
            }
        }

        let playerItem: AVPlayerItem? = await withCheckedContinuation { continuation in
            let resumeGuard = HomeCarouselVideoRequestResumeGuard()
            let started = Date()
            _ = PHImageManager.default().requestPlayerItem(
                forVideo: phAsset,
                options: options
            ) { item, info in
                // Critical: do not read item?.asset — that forces a full iCloud download.
                if resumeGuard.claim() {
                    continuation.resume(returning: item)
                    return
                }
                // Soft timeout already claimed nil — still keep a late streaming item if PhotoKit delivers.
                if let item {
                    Task { @MainActor in
                        HomeCarouselVideoSessionCache.shared.storeLateArrivingPlayerItem(
                            item,
                            localIdentifier: trimmed
                        )
                    }
                }
                if item == nil {
                    let elapsed = Date().timeIntervalSince(started)
                    let detail = DiveMediaVideoLoad.requestFailureDetail(
                        timedOut: false,
                        networkAllowed: networkAllowed,
                        elapsedSeconds: elapsed,
                        isInCloud: info?[PHImageResultIsInCloudKey] as? Bool,
                        errorDescription: (info?[PHImageErrorKey] as? NSError)?.localizedDescription,
                        hasSeenProgress: progressState.hasSeenProgress
                    )
                    Task { @MainActor in
                        HomeMediaCarouselDebug.videoAssetRequestFailed(
                            localIdentifier: trimmed,
                            quality: "homeSimple",
                            detail: detail
                        )
                    }
                }
            }

            // Soft timeout only when iCloud shows no progress; hard cap while a download crawls.
            let softTimeout = HomeCarouselVideoPresentation.requestTimeoutSeconds
            guard softTimeout > 0 else { return }
            Task.detached {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    let elapsed = Date().timeIntervalSince(started)
                    guard DiveMediaVideoLoad.shouldFailVideoRequest(
                        elapsedSeconds: elapsed,
                        hasSeenProgress: progressState.hasSeenProgress,
                        softTimeoutSeconds: softTimeout,
                        hardTimeoutSeconds: DiveMediaVideoLoad.hardTimeoutSeconds
                    ) else { continue }

                    if resumeGuard.claim() {
                        Task { @MainActor in
                            HomeMediaCarouselDebug.videoAssetRequestFailed(
                                localIdentifier: trimmed,
                                quality: "homeSimple",
                                detail: DiveMediaVideoLoad.requestFailureDetail(
                                    timedOut: true,
                                    networkAllowed: networkAllowed,
                                    elapsedSeconds: elapsed,
                                    isInCloud: nil,
                                    errorDescription: nil,
                                    hasSeenProgress: progressState.hasSeenProgress
                                )
                            )
                        }
                        continuation.resume(returning: nil)
                    }
                    return
                }
            }
        }

        guard let playerItem else { return nil }
        DiveMutedVideoAudioSession.activateForMutedPlayback()
        let player = AVPlayer(playerItem: playerItem)
        player.isMuted = true
        return player
    }
}

/// Tracks iCloud progress so the soft timeout keeps waiting while a stream/download advances.
private final class HomeCarouselVideoProgressState: @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var seenProgress = false

    nonisolated init() {}

    nonisolated func noteProgress(_ progress: Double) {
        guard progress > 0 else { return }
        lock.lock()
        seenProgress = true
        lock.unlock()
    }

    nonisolated var hasSeenProgress: Bool {
        lock.lock()
        defer { lock.unlock() }
        return seenProgress
    }
}

private final class HomeCarouselVideoRequestResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var claimed = false

    nonisolated init() {}

    nonisolated func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
#endif
