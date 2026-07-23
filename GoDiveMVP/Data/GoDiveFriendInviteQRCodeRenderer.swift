import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Renders invite QR codes for the share sheet.
enum GoDiveFriendInviteQRCodeRenderer: Sendable {
    @MainActor
    static func image(for url: URL, dimension: CGFloat = 220) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = max(1, dimension / output.extent.width)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
