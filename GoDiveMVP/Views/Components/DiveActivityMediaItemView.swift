import SwiftData
import SwiftUI
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#endif

/// One pager page — image or video for a **`DiveMediaPhoto`** row. Loads on demand from the referenced Photos
/// asset; prunes the row if the original was deleted.
struct DiveActivityMediaItemView: View {
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.displayScale) private var displayScale
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNetworkConnectivityMonitor.self) private var networkConnectivity

    let media: DiveMediaPhoto
    var timeZoneOffsetSeconds: Int?
    var captureContext: DiveMediaCaptureContext?
    var showsCaptureDateOverlay = true
    var captureOverlayBottomInset: CGFloat = 0
    var showsMarineLifeTagButton = false
    var marineLifeTagIsActive = false
    /// Top padding below the dive tab bar (**`DiveActivityOverviewPanelMetrics.marineLifeTagButtonTopPadding`**).
    var marineLifeTagTopInset: CGFloat = 0
    var onTagMarineLife: (() -> Void)?
    var isVideoPlaybackActive: Bool = false
    var loopsVideoPlayback: Bool = false
    /// Bumped when dive media becomes active (deep link, tab switch, async hydrate) to remount the player.
    var videoPlaybackEpoch: Int = 0

    @State private var isHoldingVideoPause = false
    @State private var layoutWidth: CGFloat = 0
    #if canImport(UIKit)
    @State private var previewImage: UIImage?
    @State private var videoPosterImage: UIImage?
    @State private var videoPosterLoadFinished = false
    @State private var imageLoadFinished = false
    #endif

    private var isVideo: Bool {
        media.resolvedMediaKind == .video
    }

    private var captureOverlay: (dateTimeLine: String, divePositionLine: String?)? {
        DiveActivityMediaPresentation.mediaPreviewCaptureOverlayLines(
            media: media,
            captureContext: captureContext,
            timeZoneOffsetSeconds: timeZoneOffsetSeconds,
            displayUnits: diveDisplayUnitSystem
        )
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            mediaContent

            if showsMarineLifeTagButton, let onTagMarineLife {
                VStack(alignment: .leading, spacing: 0) {
                    DiveActivityMediaMarineLifeTagButton(
                        isActive: marineLifeTagIsActive,
                        action: onTagMarineLife
                    )
                        .padding(.top, marineLifeTagTopInset)
                        .padding(.leading, AppTheme.Spacing.md)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            layoutWidth = newWidth
        }
        .modifier(
            DiveActivityVideoHoldToPauseModifier(
                isEnabled: isVideo,
                isHoldingVideoPause: $isHoldingVideoPause
            )
        )
        .onChange(of: isVideoPlaybackActive) { _, isActive in
            if !isActive {
                isHoldingVideoPause = false
            }
        }
        .onDisappear {
            isHoldingVideoPause = false
        }
        .onAppear {
            DiveMediaPreviewStorage.seedSessionCacheIfNeeded(for: media)
            #if canImport(UIKit)
            if previewImage == nil {
                previewImage = sessionCachedImage ?? storedPreviewImage
            }
            if videoPosterImage == nil {
                videoPosterImage = sessionCachedImage ?? storedPreviewImage
            }
            #endif
        }
        .onChange(of: isVideoPlaybackActive) { _, isActive in
            guard isActive else { return }
            reloadActiveMediaIfNeeded()
        }
        .task(id: mediaLoadTaskID) {
            switch media.resolvedMediaKind {
            case .image:
                await loadPreviewImageIfNeeded()
            case .video:
                await loadVideoPosterIfNeeded()
            }
        }
    }

    private var mediaLoadTaskID: String {
        switch media.resolvedMediaKind {
        case .video:
            return "\(media.id.uuidString)-video"
        case .image:
            return "\(media.id.uuidString)-image-\(Int(layoutWidth * displayScale))"
        }
    }

    #if canImport(UIKit)
    private var sessionCachedImage: UIImage? {
        guard let identifier = media.libraryAssetLocalIdentifier else { return nil }
        return HomeMediaHighlightSessionCache.shared.bestCachedImage(localIdentifier: identifier)
    }

    private var storedPreviewImage: UIImage? {
        DiveMediaPreviewStorage.storedPreviewImage(for: media)
    }

    private var displayedPreviewImage: UIImage? {
        sessionCachedImage ?? previewImage ?? storedPreviewImage
    }

    private var displayedVideoPosterImage: UIImage? {
        sessionCachedImage ?? videoPosterImage ?? storedPreviewImage
    }
    #endif

    private func pruneIfAssetMissing() {
        #if canImport(Photos)
        DiveMediaReferencePruning.pruneIfAssetMissing(media, modelContext: modelContext)
        #endif
    }

    private var mediaContent: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                switch media.resolvedMediaKind {
                case .image:
                    imagePage
                case .video:
                    videoPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsCaptureDateOverlay, let overlay = captureOverlay {
                captureOverlayBadge(dateTimeLine: overlay.dateTimeLine, divePositionLine: overlay.divePositionLine)
                    .padding(.bottom, captureOverlayBottomInset)
            }
        }
    }

    @ViewBuilder
    private var videoPage: some View {
        ZStack {
            videoPosterPage

            DiveActivityVideoPlayerView(
                source: media.videoPlaybackSource,
                isPlaybackActive: isVideoPlaybackActive,
                loopsPlayback: loopsVideoPlayback,
                libraryVideoQuality: DiveActivityMediaPresentation.overviewLibraryVideoQuality,
                usesProgressiveFidelity: true,
                screenPixelWidth: layoutWidth * displayScale,
                initialPosterImage: displayedVideoPosterImage,
                isPausedByUserHold: isHoldingVideoPause,
                onAssetMissing: pruneIfAssetMissing,
                clearsSharedSessionPlaybackOnDisappear: true
            )
            .id("\(media.id)-epoch-\(videoPlaybackEpoch)")
        }
    }

    @ViewBuilder
    private var videoPosterPage: some View {
        GeometryReader { geometry in
            #if canImport(UIKit)
            if let displayedVideoPosterImage {
                Image(uiImage: displayedVideoPosterImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .accessibilityLabel("Dive video poster")
            } else if DiveMediaPreviewPersistence.showsMissingMediaPlaceholder(
                hasDisplayedImage: displayedVideoPosterImage != nil,
                loadFinished: videoPosterLoadFinished
            ) {
                missingImage(in: geometry.size, systemImage: "video", showsOfflineIndicator: !networkConnectivity.isConnected)
            } else {
                loadingMediaPlaceholder(in: geometry.size)
            }
            #else
            missingImage(in: geometry.size, systemImage: "video")
            #endif
        }
    }

    @ViewBuilder
    private var imagePage: some View {
        GeometryReader { geometry in
            #if canImport(UIKit)
            if let displayedPreviewImage {
                Image(uiImage: displayedPreviewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .accessibilityLabel("Dive photo")
            } else if DiveMediaPreviewPersistence.showsMissingMediaPlaceholder(
                hasDisplayedImage: displayedPreviewImage != nil,
                loadFinished: imageLoadFinished
            ) {
                missingImage(in: geometry.size, systemImage: "photo", showsOfflineIndicator: !networkConnectivity.isConnected)
            } else {
                loadingMediaPlaceholder(in: geometry.size)
            }
            #else
            missingImage(in: geometry.size, systemImage: "photo")
            #endif
        }
    }

    #if canImport(UIKit) && canImport(Photos)
    private func reloadActiveMediaIfNeeded() {
        switch media.resolvedMediaKind {
        case .image:
            imageLoadFinished = false
        case .video:
            videoPosterLoadFinished = false
        }
    }

    private func loadVideoPosterIfNeeded() async {
        guard media.resolvedMediaKind == .video,
              let identifier = media.libraryAssetLocalIdentifier else {
            videoPosterImage = nil
            videoPosterLoadFinished = true
            return
        }

        if storedPreviewImage == nil, sessionCachedImage == nil {
            videoPosterLoadFinished = false
        }
        let screenPixelWidth = layoutWidth > 0
            ? layoutWidth * displayScale
            : DiveMediaProgressivePresentation.posterImageEdge
        let posterSize = DiveMediaProgressivePresentation.posterTargetSize(
            screenPixelWidth: screenPixelWidth
        )
        var receivedFrame = false
        await DiveMediaReferenceLoader.loadImageProgressive(
            localIdentifier: identifier,
            targetSize: posterSize,
            deliveryMode: .opportunistic
        ) { image, _ in
            videoPosterImage = image
            receivedFrame = true
            DiveMediaPreviewStorage.persistPreview(from: image, on: media, modelContext: modelContext)
        }
        if !receivedFrame, networkConnectivity.isConnected {
            DiveMediaReferencePruning.pruneIfAssetMissing(media, modelContext: modelContext)
        }
        videoPosterLoadFinished = true
        if receivedFrame {
            DiveMediaScopeCache.shared.noteMediaLoaded(
                libraryIdentifier: identifier,
                tier: .preview
            )
        }
    }

    private func loadPreviewImageIfNeeded() async {
        guard media.resolvedMediaKind == .image, let identifier = media.libraryAssetLocalIdentifier else {
            previewImage = nil
            imageLoadFinished = true
            return
        }
        if storedPreviewImage == nil, sessionCachedImage == nil {
            imageLoadFinished = false
        }
        let screenPixelWidth = layoutWidth > 0
            ? layoutWidth * displayScale
            : DiveMediaPreviewPersistence.storedPreviewEdge
        let targetSize: CGSize
        if networkConnectivity.isConnected, layoutWidth > 0 {
            let edge = DiveActivityMediaPresentation.fullScreenImageTargetEdge(
                screenPixelWidth: screenPixelWidth
            )
            targetSize = CGSize(width: edge, height: edge)
        } else {
            targetSize = DiveMediaProgressivePresentation.posterTargetSize(
                screenPixelWidth: screenPixelWidth
            )
        }
        var receivedFrame = false
        var receivedFinal = false
        await DiveMediaReferenceLoader.loadImageProgressive(
            localIdentifier: identifier,
            targetSize: targetSize,
            deliveryMode: .opportunistic
        ) { image, isFinal in
            previewImage = image
            receivedFrame = true
            if isFinal {
                receivedFinal = true
            }
            DiveMediaPreviewStorage.persistPreview(from: image, on: media, modelContext: modelContext)
        }
        if !receivedFrame, networkConnectivity.isConnected {
            DiveMediaReferencePruning.pruneIfAssetMissing(media, modelContext: modelContext)
        }
        imageLoadFinished = true
        if receivedFrame {
            let tier: DiveMediaRetainedTier = receivedFinal ? .full : .preview
            DiveMediaScopeCache.shared.noteMediaLoaded(
                libraryIdentifier: identifier,
                tier: tier
            )
        }
    }
    #else
    private func loadPreviewImageIfNeeded() async {}
    #endif

    private func captureOverlayBadge(dateTimeLine: String, divePositionLine: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(dateTimeLine)
            if let divePositionLine {
                Text(divePositionLine)
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.55), in: Capsule())
        .padding(AppTheme.Spacing.md)
        .accessibilityLabel(
            DiveActivityMediaPresentation.mediaPreviewCaptureAccessibilityLabel(
                media: media,
                captureContext: captureContext,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds,
                displayUnits: diveDisplayUnitSystem
            ) ?? "Captured \(dateTimeLine)"
        )
    }

    private func missingImage(
        in size: CGSize,
        systemImage: String = "photo",
        showsOfflineIndicator: Bool = false
    ) -> some View {
        ZStack {
            AppTheme.Colors.surfaceMuted.opacity(0.5)
            if showsOfflineIndicator {
                OfflineMediaUnavailableIndicator()
            } else {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func loadingMediaPlaceholder(in size: CGSize) -> some View {
        AppTheme.Colors.surfaceMuted.opacity(0.35)
            .frame(width: size.width, height: size.height)
    }
}

/// **`onLongPressGesture(maximumDistance:)`** — movement fails the press so horizontal pager swipes win.
private struct DiveActivityVideoHoldToPauseModifier: ViewModifier {
    let isEnabled: Bool
    @Binding var isHoldingVideoPause: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.onLongPressGesture(
                minimumDuration: DiveActivityVideoPlaybackPolicy.holdPauseMinimumDurationSeconds,
                maximumDistance: DiveActivityVideoPlaybackPolicy.holdPauseMaximumMovementPoints,
                pressing: { isPressing in
                    isHoldingVideoPause = isPressing
                },
                perform: {}
            )
        } else {
            content
        }
    }
}
