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
    /// When true, use stored / session soft JPEG only (no PhotoKit) — for large scrollable grids.
    var prefersStoredPreviewOnly: Bool = false

    @Environment(\.modelContext) private var modelContext
    #if canImport(UIKit)
    @State private var thumbnailImage: UIImage?
    @State private var thumbnailLoadFinished = false
    #endif

    var body: some View {
        ZStack {
            thumbnailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            if showsPlayBadge, media.resolvedMediaKind == .video {
                Image(systemName: "play.circle.fill")
                    .font(playBadgeFont)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.35))
                    .allowsHitTesting(false)
            }
        }
        .frame(
            width: size > 0 ? size : nil,
            height: size > 0 ? size : nil
        )
        .frame(maxWidth: size > 0 ? nil : .infinity, maxHeight: size > 0 ? nil : .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: loadTaskID) {
            await loadThumbnailIfNeeded()
        }
        .onAppear {
            DiveMediaPreviewStorage.seedSessionCacheIfNeeded(for: media)
            #if canImport(UIKit)
            if thumbnailImage == nil, let stored = storedThumbnailImage {
                thumbnailImage = stored
            }
            #endif
        }
    }

    private var loadTaskID: String {
        "\(media.id.uuidString)-\(Int(size))-\(prefersStoredPreviewOnly ? "stored" : "full")"
    }

    private var playBadgeFont: Font {
        size >= DiveActivityMediaPresentation.carouselThumbnailSize * 0.85
            ? .title2
            : .caption.weight(.semibold)
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        #if canImport(UIKit)
        if let displayedThumbnailImage {
            Image(uiImage: displayedThumbnailImage)
                .resizable()
                .scaledToFill()
        } else if DiveMediaPreviewPersistence.showsMissingMediaPlaceholder(
            hasDisplayedImage: displayedThumbnailImage != nil,
            loadFinished: thumbnailLoadFinished
        ) {
            missingThumbnail
        } else {
            loadingThumbnail
        }
        #else
        missingThumbnail
        #endif
    }

    #if canImport(UIKit)
    private var storedThumbnailImage: UIImage? {
        DiveMediaPreviewStorage.storedPreviewImage(for: media)
    }

    private var displayedThumbnailImage: UIImage? {
        thumbnailImage ?? storedThumbnailImage
    }
    #endif

    private var loadingThumbnail: some View {
        AppTheme.Colors.surfaceMuted.opacity(0.35)
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
        DiveMediaPreviewStorage.seedSessionCacheIfNeeded(for: media)
        if let stored = storedThumbnailImage {
            thumbnailImage = stored
            thumbnailLoadFinished = true
            if prefersStoredPreviewOnly {
                return
            }
        } else if prefersStoredPreviewOnly {
            thumbnailLoadFinished = true
            return
        }

        let identifier = DiveMediaLibraryIdentifierRepair.resolveLocalIdentifierIfNeeded(
            for: media,
            modelContext: modelContext
        )
        guard let identifier else {
            thumbnailLoadFinished = true
            if DiveMediaCloudIdentifierStorage.isPresent(media.photosCloudIdentifier)
                || media.libraryAssetLocalIdentifier != nil {
                DiveMediaReferencePruning.pruneIfAssetMissing(media, modelContext: modelContext)
            }
            return
        }
        if storedThumbnailImage == nil {
            thumbnailLoadFinished = false
        }
        let requestSize = size > 0 ? size : LinkedMediaGridPresentation.gridThumbnailPointSize
        let edge = size > 0
            ? max(requestSize * 2, 1)
            : LinkedMediaGridPresentation.photoKitRequestEdge
        let image = await DiveMediaReferenceLoader.image(
            localIdentifier: identifier,
            targetSize: CGSize(width: edge, height: edge),
            deliveryMode: .opportunistic
        )
        if let image {
            thumbnailImage = image
            DiveMediaPreviewStorage.persistPreview(from: image, on: media, modelContext: modelContext)
            _ = DiveMediaLibraryIdentifierRepair.captureCloudIdentifierIfNeeded(for: media)
            try? modelContext.save()
        } else if thumbnailImage == nil, storedThumbnailImage == nil {
            DiveMediaReferencePruning.pruneIfAssetMissing(media, modelContext: modelContext)
        }
        thumbnailLoadFinished = true
        #else
        thumbnailImage = nil
        thumbnailLoadFinished = true
        #endif
    }
    #else
    private func loadThumbnailIfNeeded() async {}
    #endif
}
