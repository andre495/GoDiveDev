import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Square image or video-frame thumbnail for carousel and depth-profile markers.
struct DiveActivityMediaThumbnailView: View {
    let media: DiveMediaPhoto
    var size: CGFloat = DiveActivityMediaPresentation.carouselThumbnailSize
    var cornerRadius: CGFloat = DiveActivityMediaPresentation.carouselThumbnailCornerRadius
    var showsPlayBadge: Bool = true

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
    }

    private var playBadgeFont: Font {
        size >= DiveActivityMediaPresentation.carouselThumbnailSize * 0.85
            ? .title2
            : .caption.weight(.semibold)
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        switch media.resolvedMediaKind {
        case .image:
            imageThumbnail
        case .video:
            DiveActivityVideoThumbnailView(fileURL: media.videoFileURL, maxPixelSize: size * 2)
        }
    }

    @ViewBuilder
    private var imageThumbnail: some View {
        #if canImport(UIKit)
        if let image = UIImage(data: media.mediaData) {
            Image(uiImage: image)
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
            Image(systemName: "photo")
                .foregroundStyle(AppTheme.Colors.tabUnselected)
        }
    }
}

// MARK: - Video frame

struct DiveActivityVideoThumbnailView: View {
    let fileURL: URL?
    var maxPixelSize: CGFloat = DiveActivityMediaPresentation.carouselThumbnailSize * 2

    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    AppTheme.Colors.surfaceMuted
                    Image(systemName: "video")
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                }
            }
            #else
            ZStack {
                AppTheme.Colors.surfaceMuted
                Image(systemName: "video")
            }
            #endif
        }
        .task(id: fileURL?.absoluteString) {
            await loadThumbnail()
        }
        .onAppear {
            guard thumbnail == nil else { return }
            Task { await loadThumbnail() }
        }
    }

    #if canImport(UIKit) && canImport(AVFoundation)
    private func loadThumbnail() async {
        guard let fileURL else {
            thumbnail = nil
            return
        }
        if let cached = DiveActivityVideoThumbnailCache.image(for: fileURL, maxPixelSize: maxPixelSize) {
            thumbnail = cached
            return
        }
        let asset = AVURLAsset(url: fileURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        do {
            let frame = try await generator.image(at: time)
            let image = UIImage(cgImage: frame.image)
            DiveActivityVideoThumbnailCache.store(image, for: fileURL, maxPixelSize: maxPixelSize)
            thumbnail = image
        } catch {
            thumbnail = nil
        }
    }
    #else
    private func loadThumbnail() async {
        thumbnail = nil
    }
    #endif
}

#if canImport(UIKit)
enum DiveActivityVideoThumbnailCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for fileURL: URL, maxPixelSize: CGFloat) -> UIImage? {
        cache.object(forKey: cacheKey(fileURL: fileURL, maxPixelSize: maxPixelSize))
    }

    static func store(_ image: UIImage, for fileURL: URL, maxPixelSize: CGFloat) {
        cache.setObject(image, forKey: cacheKey(fileURL: fileURL, maxPixelSize: maxPixelSize))
    }

    private static func cacheKey(fileURL: URL, maxPixelSize: CGFloat) -> NSString {
        "\(fileURL.absoluteString)|\(Int(maxPixelSize))" as NSString
    }
}
#endif
