import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// One pager page — image or video for a **`DiveMediaPhoto`** row.
struct DiveActivityMediaItemView: View {
    let media: DiveMediaPhoto

    var body: some View {
        Group {
            switch media.resolvedMediaKind {
            case .image:
                imagePage
            case .video:
                DiveActivityVideoPlayerView(fileURL: media.videoFileURL)
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
