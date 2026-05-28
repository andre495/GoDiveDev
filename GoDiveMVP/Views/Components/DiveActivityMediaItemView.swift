import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// One pager page — image or video for a **`DiveMediaPhoto`** row.
struct DiveActivityMediaItemView: View {
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem

    let media: DiveMediaPhoto
    var timeZoneOffsetSeconds: Int?
    var captureContext: DiveMediaCaptureContext?
    var showsCaptureDateOverlay = true
    var showsMarineLifeTagButton = false
    /// Top padding below the dive tab bar (**`DiveActivityOverviewPanelMetrics.marineLifeTagButtonTopPadding`**).
    var marineLifeTagTopInset: CGFloat = 0
    var onTagMarineLife: (() -> Void)?
    var isVideoPlaybackActive: Bool = false
    var loopsVideoPlayback: Bool = false

    @State private var isHoldingVideoPause = false
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
                    DiveActivityMediaMarineLifeTagButton(action: onTagMarineLife)
                        .padding(.top, marineLifeTagTopInset)
                        .padding(.leading, AppTheme.Spacing.md)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
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
        "\(media.id.uuidString)-\(media.mediaData.count)-\(media.resolvedMediaKind.rawValue)"
    }

    private var mediaContent: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                switch media.resolvedMediaKind {
                case .image:
                    imagePage
                case .video:
                    DiveActivityVideoPlayerView(
                        fileURL: media.videoFileURL,
                        isPlaybackActive: isVideoPlaybackActive,
                        loopsPlayback: loopsVideoPlayback,
                        isPausedByUserHold: isHoldingVideoPause
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsCaptureDateOverlay, let overlay = captureOverlay {
                captureOverlayBadge(dateTimeLine: overlay.dateTimeLine, divePositionLine: overlay.divePositionLine)
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

    #if canImport(UIKit)
    private func loadPreviewImageIfNeeded() async {
        guard media.resolvedMediaKind == .image, !media.mediaData.isEmpty else {
            previewImage = nil
            return
        }
        previewImage = await DiveMediaPhotoImageLoader.thumbnail(
            from: media.mediaData,
            maxPixelSize: 2_048
        )
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
