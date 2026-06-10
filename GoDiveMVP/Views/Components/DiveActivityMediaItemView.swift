import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// One pager page — image or video for a **`DiveMediaPhoto`** row. Loads on demand from the referenced Photos
/// asset; prunes the row if the original was deleted.
struct DiveActivityMediaItemView: View {
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.displayScale) private var displayScale
    @Environment(\.modelContext) private var modelContext

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

    @State private var isHoldingVideoPause = false
    @State private var layoutWidth: CGFloat = 0
    #if canImport(UIKit)
    @State private var previewImage: UIImage?
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
        .task(id: imageLoadTaskID) {
            await loadPreviewImageIfNeeded()
        }
    }

    private var imageLoadTaskID: String {
        "\(media.id.uuidString)-\(media.resolvedMediaKind.rawValue)-\(Int(layoutWidth * displayScale))"
    }

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
                    DiveActivityVideoPlayerView(
                        source: media.videoPlaybackSource,
                        isPlaybackActive: isVideoPlaybackActive,
                        loopsPlayback: loopsVideoPlayback,
                        libraryVideoQuality: DiveActivityMediaPresentation.overviewLibraryVideoQuality,
                        isPausedByUserHold: isHoldingVideoPause,
                        onAssetMissing: pruneIfAssetMissing
                    )
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
    private var imagePage: some View {
        GeometryReader { geometry in
            #if canImport(UIKit)
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .accessibilityLabel("Dive photo")
            } else {
                missingImage(in: geometry.size)
            }
            #else
            missingImage(in: geometry.size)
            #endif
        }
    }

    #if canImport(UIKit) && canImport(Photos)
    private func loadPreviewImageIfNeeded() async {
        guard media.resolvedMediaKind == .image, let identifier = media.libraryAssetLocalIdentifier else {
            previewImage = nil
            return
        }
        guard layoutWidth > 0 else { return }
        let edge = DiveActivityMediaPresentation.fullScreenImageTargetEdge(
            screenPixelWidth: layoutWidth * displayScale
        )
        let image = await DiveMediaReferenceLoader.image(
            localIdentifier: identifier,
            targetSize: CGSize(width: edge, height: edge)
        )
        if image == nil {
            DiveMediaReferencePruning.pruneIfAssetMissing(media, modelContext: modelContext)
        }
        previewImage = image
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

    private func missingImage(in size: CGSize) -> some View {
        ZStack {
            AppTheme.Colors.surfaceMuted.opacity(0.5)
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
        }
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
