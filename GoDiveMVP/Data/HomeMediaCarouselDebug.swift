import Foundation
import os

/// Structured logging for Home featured-media carousel load / playback.
///
/// Filter in **Console.app** or Xcode: subsystem = app bundle id, category **`HomeMediaCarousel`**.
enum HomeMediaCarouselDebug: Sendable {

    /// Flip to **`false`** to silence carousel media logs.
    /// Default **on** in DEBUG only — Release stays quiet (OWASP Phase 5).
    #if DEBUG
    nonisolated(unsafe) static var isEnabled = true
    #else
    nonisolated(unsafe) static var isEnabled = false
    #endif

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "GoDiveMVP",
        category: "HomeMediaCarousel"
    )

    enum LoadOutcome: String, Sendable {
        case skippedVideoKind
        case missingLibraryIdentifier
        case sessionHeroHit
        case sessionPreviewHit
        case storedPreviewHit
        case progressiveFinal
        case progressivePartial
        case loadFailed
        case loadTaskCancelled
    }

    enum VideoResolveOutcome: String, Sendable {
        case began
        case restoredSnapshot
        case previewReady
        case fullReady
        case failed
        case cancelled
    }

    static func carouselVisibility(visible: Bool, slideCount: Int) {
        guard isEnabled else { return }
        logger.info("carousel visible=\(visible, privacy: .public) slides=\(slideCount, privacy: .public)")
    }

    static func scenePhase(isActive: Bool) {
        guard isEnabled else { return }
        logger.info("scenePhase active=\(isActive, privacy: .public)")
    }

    static func highlightsUpdated(mediaIDs: [UUID], keepsAllSlidesLoaded: Bool) {
        guard isEnabled else { return }
        let ids = mediaIDs.map(\.uuidString).joined(separator: ",")
        logger.info("""
        highlights count=\(mediaIDs.count, privacy: .public) keepsAllLoaded=\(keepsAllSlidesLoaded, privacy: .public) \
        media=[\(ids, privacy: .public)]
        """)
    }

    static func warmupScheduled(alreadyWarmed: Bool, displayableBeforeWarm: Bool) {
        guard isEnabled else { return }
        logger.info("""
        warmup schedule alreadyWarmed=\(alreadyWarmed, privacy: .public) \
        displayableBeforeWarm=\(displayableBeforeWarm, privacy: .public)
        """)
    }

    static func warmupRepinned(libraryIdentifiers: [String], mediaIDs: [UUID]) {
        guard isEnabled else { return }
        let ids = mediaIDs.map(\.uuidString).joined(separator: ",")
        logger.info("""
        session repin libraries=\(libraryIdentifiers.count, privacy: .public) \
        media=[\(ids, privacy: .public)]
        """)
    }

    static func warmupFinished(
        mediaIDs: [UUID],
        displayableByMediaID: [UUID: Bool]
    ) {
        guard isEnabled else { return }
        let summary = mediaIDs.map { id in
            let ok = displayableByMediaID[id] == true
            return "\(id.uuidString):\(ok ? "ready" : "pending")"
        }.joined(separator: " ")
        logger.info("warmup finished \(summary, privacy: .public)")
    }

    static func warmImage(
        mediaID: UUID,
        quality: String,
        cacheHit: Bool,
        stored: Bool
    ) {
        guard isEnabled else { return }
        logger.info("""
        warm image media=\(mediaID.uuidString, privacy: .public) quality=\(quality, privacy: .public) \
        cacheHit=\(cacheHit, privacy: .public) stored=\(stored, privacy: .public)
        """)
    }

    static func warmVideo(mediaID: UUID, cacheHit: Bool, stored: Bool, loaded: Bool? = nil) {
        guard isEnabled else { return }
        if let loaded {
            logger.info("""
            warm video media=\(mediaID.uuidString, privacy: .public) \
            cacheHit=\(cacheHit, privacy: .public) loaded=\(loaded, privacy: .public) \
            stored=\(stored, privacy: .public)
            """)
        } else {
            logger.info("""
            warm video media=\(mediaID.uuidString, privacy: .public) \
            cacheHit=\(cacheHit, privacy: .public) stored=\(stored, privacy: .public)
            """)
        }
    }

    static func slideSelected(
        index: Int,
        slideCount: Int,
        mediaID: UUID,
        mediaKind: String
    ) {
        guard isEnabled else { return }
        logger.info("""
        slide selected index=\(index, privacy: .public)/\(slideCount, privacy: .public) \
        media=\(mediaID.uuidString, privacy: .public) kind=\(mediaKind, privacy: .public)
        """)
    }

    static func slidePlayback(
        index: Int,
        mediaID: UUID,
        isActive: Bool,
        playbackAllowed: Bool,
        shouldLoad: Bool
    ) {
        guard isEnabled else { return }
        logger.info("""
        slide playback index=\(index, privacy: .public) media=\(mediaID.uuidString, privacy: .public) \
        active=\(isActive, privacy: .public) allowed=\(playbackAllowed, privacy: .public) \
        shouldLoad=\(shouldLoad, privacy: .public)
        """)
    }

    static func loadTaskBegan(
        index: Int,
        mediaID: UUID,
        mediaKind: String,
        libraryIdentifier: String?,
        hadSessionHero: Bool,
        hadSessionPreview: Bool,
        hadStoredPreview: Bool,
        containerWidth: CGFloat
    ) {
        guard isEnabled else { return }
        let library = libraryIdentifier ?? "nil"
        logger.info("""
        load began index=\(index, privacy: .public) media=\(mediaID.uuidString, privacy: .public) \
        kind=\(mediaKind, privacy: .public) library=\(library, privacy: .public) \
        sessionHero=\(hadSessionHero, privacy: .public) sessionPreview=\(hadSessionPreview, privacy: .public) \
        storedPreview=\(hadStoredPreview, privacy: .public) width=\(Int(containerWidth), privacy: .public)
        """)
    }

    static func loadTaskEnded(
        index: Int,
        mediaID: UUID,
        outcome: LoadOutcome,
        hadDisplayedImage: Bool
    ) {
        guard isEnabled else { return }
        logger.info("""
        load ended index=\(index, privacy: .public) media=\(mediaID.uuidString, privacy: .public) \
        outcome=\(outcome.rawValue, privacy: .public) displayed=\(hadDisplayedImage, privacy: .public)
        """)
    }

    static func videoLayer(
        index: Int,
        mediaID: UUID,
        mounted: Bool,
        isPlaybackActive: Bool
    ) {
        guard isEnabled else { return }
        logger.info("""
        video layer index=\(index, privacy: .public) media=\(mediaID.uuidString, privacy: .public) \
        mounted=\(mounted, privacy: .public) playbackActive=\(isPlaybackActive, privacy: .public)
        """)
    }

    static func videoResolve(
        sourceKey: String,
        outcome: VideoResolveOutcome,
        detail: String? = nil
    ) {
        guard isEnabled else { return }
        let suffix = detail.map { " (\($0))" } ?? ""
        logger.info("""
        video resolve source=\(sourceKey, privacy: .public) \
        -> \(outcome.rawValue, privacy: .public)\(suffix, privacy: .public)
        """)
    }

    static func videoAssetRequestFailed(
        localIdentifier: String,
        quality: String,
        detail: String
    ) {
        guard isEnabled else { return }
        logger.error("""
        video asset request failed library=\(localIdentifier, privacy: .public) \
        quality=\(quality, privacy: .public) \(detail, privacy: .public)
        """)
    }

    static func videoLoadProgress(
        localIdentifier: String,
        progress: Double,
        errorDescription: String? = nil
    ) {
        guard isEnabled else { return }
        let percent = Int((progress * 100).rounded())
        let suffix = errorDescription.map { " error=\($0)" } ?? ""
        logger.info("""
        video load progress library=\(localIdentifier, privacy: .public) \
        \(percent, privacy: .public)%\(suffix, privacy: .public)
        """)
    }

    static func stillRequestFellBackToDegraded(
        localIdentifier: String,
        elapsedSeconds: Double,
        hadDegradedFrame: Bool
    ) {
        guard isEnabled else { return }
        logger.error("""
        still request timed out library=\(localIdentifier, privacy: .public) \
        \(String(format: "%.1fs", elapsedSeconds), privacy: .public) \
        degradedFallback=\(hadDegradedFrame, privacy: .public)
        """)
    }

    static func videoAssetRequestSucceeded(
        localIdentifier: String,
        quality: String,
        elapsedSeconds: Double
    ) {
        guard isEnabled else { return }
        logger.info("""
        video asset request ready library=\(localIdentifier, privacy: .public) \
        quality=\(quality, privacy: .public) \(String(format: "%.2fs", elapsedSeconds), privacy: .public)
        """)
    }
}
