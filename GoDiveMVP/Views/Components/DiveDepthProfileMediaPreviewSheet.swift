import SwiftUI

/// Full-sheet preview when a depth-profile media marker is tapped.
struct DiveDepthProfileMediaPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let media: DiveMediaPhoto
    var timeZoneOffsetSeconds: Int?
    var captureContext: DiveMediaCaptureContext?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DiveActivityMediaItemView(
                media: media,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds,
                captureContext: captureContext,
                isVideoPlaybackActive: true,
                loopsVideoPlayback: true
            )

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.45))
            }
            .buttonStyle(.plain)
            .padding(AppTheme.Spacing.md)
            .accessibilityLabel("Close preview")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(media.resolvedMediaKind == .video ? "Dive video preview" : "Dive photo preview")
    }
}
