import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Catalog photos for Field Guide surfaces.
///
/// Prefers bundled JPEGs under **`Resources/MarineLifePhotos/`** (offline), then remote URLs.
enum FieldGuideMarineLifeImageLayout {
    /// Shared 4:3 crop for species mosaic tiles.
    static let mosaicAspectRatio: CGFloat = 4.0 / 3.0
    /// Keeps mosaic cards the same height below the photo.
    static let mosaicLabelBlockHeight: CGFloat = 88
    /// Detail hero height before safe-area extension.
    static let detailHeroBaseHeight: CGFloat = 280
    /// Species detail hero — full width, no crop; letterbox on **`screenBackgroundGradient`**.
    static let detailHeroDefaultContentMode: FieldGuideMarineLifeCatalogImageContentMode = .fit
}

/// How catalog photos map into a fixed bounds rect.
enum FieldGuideMarineLifeCatalogImageContentMode: Equatable {
    /// Center-crop to cover (**`scaledToFill`**) — thumbnails and compact tiles.
    case fill
    /// Letterbox inside bounds (**`scaledToFit`**) — hero bands that should show more of the subject.
    case fit
}

struct FieldGuideMarineLifeCatalogImage: View {
    enum Placement: Equatable {
        case mosaicTile(accent: Color)
        case listThumbnail(accent: Color, size: CGFloat = 56)
        case detailHero(
            alignment: Alignment = .center,
            contentMode: FieldGuideMarineLifeCatalogImageContentMode =
                FieldGuideMarineLifeImageLayout.detailHeroDefaultContentMode
        )
        case mediaSheetHero(
            height: CGFloat,
            cornerRadius: CGFloat = AppTheme.Spacing.md,
            alignment: Alignment = .center,
            contentMode: FieldGuideMarineLifeCatalogImageContentMode = .fill
        )
    }

    let imageURLString: String
    var bundleResourceName: String = ""
    let placement: Placement

    @Environment(AppNetworkConnectivityMonitor.self) private var networkConnectivity
    #if canImport(UIKit)
    @State private var bundledDecodedImage: UIImage?
    #endif

    var body: some View {
        switch placement {
        case .mosaicTile(let accent):
            boundedImage(
                height: nil,
                aspectRatio: FieldGuideMarineLifeImageLayout.mosaicAspectRatio,
                fillsAvailableHeight: false,
                cornerRadius: 0,
                accent: accent,
                alignment: .center,
                contentMode: .fill
            )
        case .listThumbnail(let accent, let size):
            boundedImage(
                height: size,
                aspectRatio: 1,
                fillsAvailableHeight: false,
                cornerRadius: 10,
                accent: accent,
                alignment: .center,
                contentMode: .fill
            )
        case .detailHero(let alignment, let contentMode):
            boundedImage(
                height: nil,
                aspectRatio: nil,
                fillsAvailableHeight: true,
                cornerRadius: 0,
                accent: AppTheme.Colors.tabUnselected,
                alignment: alignment,
                contentMode: contentMode
            )
        case .mediaSheetHero(let height, let cornerRadius, let alignment, let contentMode):
            boundedImage(
                height: height,
                aspectRatio: nil,
                fillsAvailableHeight: false,
                cornerRadius: cornerRadius,
                accent: AppTheme.Colors.tabUnselected,
                alignment: alignment,
                contentMode: contentMode
            )
        }
    }

    @ViewBuilder
    private func boundedImage(
        height: CGFloat?,
        aspectRatio: CGFloat?,
        fillsAvailableHeight: Bool,
        cornerRadius: CGFloat,
        accent: Color,
        alignment: Alignment,
        contentMode: FieldGuideMarineLifeCatalogImageContentMode
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Color.clear
            .frame(maxWidth: .infinity)
            .modifier(
                FieldGuideMarineLifeImageBoundsModifier(
                    height: height,
                    aspectRatio: aspectRatio,
                    fillsAvailableHeight: fillsAvailableHeight
                )
            )
            .overlay {
                ZStack {
                    if showsLetterboxBackdrop(for: contentMode) {
                        letterboxBackdrop
                    }
                    catalogImageFill(
                        accent: accent,
                        alignment: alignment,
                        contentMode: contentMode
                    )
                }
            }
            .clipShape(shape)
            .contentShape(shape)
    }

    @ViewBuilder
    private func catalogImageFill(
        accent: Color,
        alignment: Alignment,
        contentMode: FieldGuideMarineLifeCatalogImageContentMode
    ) -> some View {
        switch resolvedImageSource {
        case .bundledFile(let url), .cachedFile(let url):
            bundledFillImage(
                url: url,
                accent: accent,
                alignment: alignment,
                contentMode: contentMode
            )
        case .remote(let url):
            if networkConnectivity.isConnected {
                remoteFillImage(
                    url: url,
                    accent: accent,
                    alignment: alignment,
                    contentMode: contentMode
                )
            } else {
                offlineRemotePlaceholder(accent: accent)
            }
        case .none:
            placeholder(accent: accent)
        }
    }

    private var resolvedImageSource: FieldGuideMarineLifeBundledImagePresentation.ImageSource {
        FieldGuideMarineLifeBundledImagePresentation.imageSource(
            featureImageResourceName: bundleResourceName,
            featureImageURL: imageURLString
        )
    }

    @ViewBuilder
    private func bundledFillImage(
        url: URL,
        accent: Color,
        alignment: Alignment,
        contentMode: FieldGuideMarineLifeCatalogImageContentMode
    ) -> some View {
        #if canImport(UIKit)
        Group {
            if let uiImage = bundledDecodedImage {
                catalogImage(
                    Image(uiImage: uiImage),
                    accent: accent,
                    alignment: alignment,
                    contentMode: contentMode
                )
            } else {
                placeholder(accent: accent)
            }
        }
        .task(id: bundledLoadTaskID(for: url)) {
            bundledDecodedImage = await GoDiveDecodedImageCache.shared.image(
                fileURL: url,
                maxPixelEdge: bundledMaxPixelEdge
            )
        }
        #else
        placeholder(accent: accent)
        #endif
    }

    #if canImport(UIKit)
    private func bundledLoadTaskID(for url: URL) -> String {
        GoDiveDecodedImageCachePresentation.cacheKey(
            fileURL: url,
            maxPixelEdge: bundledMaxPixelEdge
        )
    }

    /// Display-sized decode budget — mosaic/list stay light; heroes keep more detail.
    private var bundledMaxPixelEdge: CGFloat {
        switch placement {
        case .mosaicTile:
            return 480
        case .listThumbnail:
            return 160
        case .detailHero, .mediaSheetHero:
            return 1_200
        }
    }
    #endif

    @ViewBuilder
    private func remoteFillImage(
        url: URL,
        accent: Color,
        alignment: Alignment,
        contentMode: FieldGuideMarineLifeCatalogImageContentMode
    ) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                catalogImage(
                    image,
                    accent: accent,
                    alignment: alignment,
                    contentMode: contentMode
                )
            case .failure:
                placeholder(accent: accent)
            case .empty:
                placeholder(accent: accent)
                    .overlay {
                        GoDiveRotateLoadingIndicator(
                            size: .compact,
                            tint: accent.opacity(0.55)
                        )
                    }
            @unknown default:
                placeholder(accent: accent)
            }
        }
    }

    @ViewBuilder
    private func catalogImage(
        _ image: Image,
        accent: Color,
        alignment: Alignment,
        contentMode: FieldGuideMarineLifeCatalogImageContentMode
    ) -> some View {
        switch contentMode {
        case .fit:
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        case .fill:
            GeometryReader { proxy in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: alignment
                    )
                    .clipped()
            }
        }
    }

    private func showsLetterboxBackdrop(
        for contentMode: FieldGuideMarineLifeCatalogImageContentMode
    ) -> Bool {
        guard contentMode == .fit else { return false }
        switch placement {
        case .detailHero:
            // Field Guide detail hero — letterbox on the screen gradient.
            return true
        case .mediaSheetHero, .mosaicTile, .listThumbnail:
            // Dive / Home / trip media heroes — image only (no blue / gradient side bars).
            return false
        }
    }

    private var letterboxBackdrop: some View {
        AppTheme.Colors.screenBackgroundGradient
    }

    private func offlineRemotePlaceholder(accent: Color) -> some View {
        placeholder(accent: accent)
            .overlay {
                OfflineMediaUnavailableIndicator(font: .caption)
            }
    }

    private func placeholder(accent: Color) -> some View {
        Rectangle()
            .fill(accent.opacity(0.12))
            .overlay {
                Image(systemName: "fish")
                    .font(placeholderIconFont)
                    .foregroundStyle(accent.opacity(0.55))
            }
    }

    private var placeholderIconFont: Font {
        switch placement {
        case .mosaicTile:
            return .title2
        case .listThumbnail:
            return .body
        case .detailHero, .mediaSheetHero:
            return .largeTitle
        }
    }
}

private struct FieldGuideMarineLifeImageBoundsModifier: ViewModifier {
    let height: CGFloat?
    let aspectRatio: CGFloat?
    let fillsAvailableHeight: Bool

    func body(content: Content) -> some View {
        if let aspectRatio {
            content
                .aspectRatio(aspectRatio, contentMode: .fit)
        } else if fillsAvailableHeight {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let height {
            content
                .frame(height: height)
        } else {
            content
        }
    }
}
