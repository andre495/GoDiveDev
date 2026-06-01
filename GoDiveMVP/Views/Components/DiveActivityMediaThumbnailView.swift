import SwiftData
import SwiftUI
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Square image or video-frame thumbnail for carousel and depth-profile markers. Loads on demand from the
/// referenced Photos asset (videos show their poster frame); prunes the row if the original was deleted.
struct DiveActivityMediaThumbnailView: View {
    let media: DiveMediaPhoto
    var size: CGFloat = DiveActivityMediaPresentation.carouselThumbnailSize
    var cornerRadius: CGFloat = DiveActivityMediaPresentation.carouselThumbnailCornerRadius
    var showsPlayBadge: Bool = true

    @Environment(\.modelContext) private var modelContext
    #if canImport(UIKit)
    @State private var thumbnailImage: UIImage?
    #endif

    var body: some View {
        ZStack {
            thumbnailContent
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            if showsPlayBadge, media.resolvedMediaKind == .video {
                Image(systemName: "play.circle.fill")
                    .font(playBadgeFont)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.35))
                    .allowsHitTesting(false)
            }
        }
        .task(id: loadTaskID) {
            await loadThumbnailIfNeeded()
        }
    }

    private var loadTaskID: String {
        "\(media.id.uuidString)-\(Int(size))"
    }

    private var playBadgeFont: Font {
        size >= DiveActivityMediaPresentation.carouselThumbnailSize * 0.85
            ? .title2
            : .caption.weight(.semibold)
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        #if canImport(UIKit)
        if let thumbnailImage {
            Image(uiImage: thumbnailImage)
                .resizable()
                .scaledToFill()
        } else {
            missingThumbnail
        }
        #else
        missingThumbnail
        #endif
    }

    private var missingThumbnail: some View {
        ZStack {
            AppTheme.Colors.surfaceMuted
            Image(systemName: media.resolvedMediaKind == .video ? "video" : "photo")
                .foregroundStyle(AppTheme.Colors.tabUnselected)
        }
    }

    #if canImport(UIKit)
    private func loadThumbnailIfNeeded() async {
        #if canImport(Photos)
        guard let identifier = media.libraryAssetLocalIdentifier else {
            thumbnailImage = nil
            return
        }
        let edge = max(size * 2, 1)
        let image = await DiveMediaReferenceLoader.image(
            localIdentifier: identifier,
            targetSize: CGSize(width: edge, height: edge),
            deliveryMode: .opportunistic
        )
        if image == nil {
            DiveMediaReferencePruning.pruneIfAssetMissing(media, modelContext: modelContext)
        }
        thumbnailImage = image
        #else
        thumbnailImage = nil
        #endif
    }
    #else
    private func loadThumbnailIfNeeded() async {}
    #endif
}
