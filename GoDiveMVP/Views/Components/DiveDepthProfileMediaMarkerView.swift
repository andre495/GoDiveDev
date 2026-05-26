import SwiftUI

/// Square media thumbnail pinned on a depth profile chart.
struct DiveDepthProfileMediaMarkerView: View {
    let media: DiveMediaPhoto

    private var size: CGFloat { DiveDepthProfileMediaPlotting.markerThumbnailSize }
    private var cornerRadius: CGFloat { DiveDepthProfileMediaPlotting.markerThumbnailCornerRadius }

    var body: some View {
        DiveActivityMediaThumbnailView(
            media: media,
            size: size,
            cornerRadius: cornerRadius,
            showsPlayBadge: true
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
        .accessibilityLabel(media.resolvedMediaKind == .video ? "Dive video on profile" : "Dive photo on profile")
        .accessibilityHint("Shows preview")
    }
}
