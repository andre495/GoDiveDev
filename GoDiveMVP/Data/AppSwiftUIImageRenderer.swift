#if canImport(UIKit)
import SwiftUI
import UIKit

/// Renders SwiftUI content without an unnecessary alpha channel (avoids ImageIO **AlphaLast** warnings on save).
enum AppSwiftUIImageRenderer {
    @MainActor
    static func opaqueUIImage<Content: View>(
        content: Content,
        scale: CGFloat
    ) -> UIImage? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// Flattens an already-opaque **`UIImage`** that still carries alpha metadata (e.g. before **`pngData()`**).
    static func opaqueFlattened(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        switch cgImage.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return image
        default:
            break
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    static func opaquePNGData(from image: UIImage) -> Data? {
        opaqueFlattened(image).pngData()
    }
}
#endif
