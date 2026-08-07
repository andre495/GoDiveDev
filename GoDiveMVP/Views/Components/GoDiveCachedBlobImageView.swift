import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// Decodes photo blobs off the main thread (equipment / cert / search artwork).
struct GoDiveCachedBlobImageView<Placeholder: View>: View {
    let data: Data?
    var maxPixelEdge: CGFloat = 128
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var decodedImage: UIImage?

    private var cacheKey: String {
        guard let data else { return "nil" }
        return GoDiveDecodedImageCachePresentation.cacheKey(data: data, maxPixelEdge: maxPixelEdge)
    }

    var body: some View {
        Group {
            if let decodedImage {
                Image(uiImage: decodedImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: cacheKey) {
            decodedImage = await GoDiveDecodedImageCache.shared.image(
                for: data,
                maxPixelEdge: maxPixelEdge
            )
        }
    }
}
#endif
