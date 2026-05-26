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
    var isVideoPlaybackActive: Bool = false
    var loopsVideoPlayback: Bool = false

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
            Group {
                switch media.resolvedMediaKind {
                case .image:
                    imagePage
                case .video:
                    DiveActivityVideoPlayerView(
                        fileURL: media.videoFileURL,
                        isPlaybackActive: isVideoPlaybackActive,
                        loopsPlayback: loopsVideoPlayback
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsCaptureDateOverlay, let overlay = captureOverlay {
                captureOverlayBadge(dateTimeLine: overlay.dateTimeLine, divePositionLine: overlay.divePositionLine)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private var imagePage: some View {
        GeometryReader { geometry in
            #if canImport(UIKit)
            if let image = UIImage(data: media.mediaData) {
                Image(uiImage: image)
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
