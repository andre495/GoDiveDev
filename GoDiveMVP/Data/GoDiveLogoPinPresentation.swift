import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Adaptive GoDive pin logo — **`GoDiveLogoPin`** asset catalog (light = dark navy pin, dark = light blue pin).
enum GoDiveLogoPinPresentation: Sendable {
    nonisolated static let assetName = "GoDiveLogoPin"

    /// SwiftUI image — appearance-aware via the asset catalog.
    static var image: Image {
        Image(assetName)
    }

    /// Light-blue pin (catalog dark appearance / Desktop **pin DARK**) — for badges on elevated tiles.
    static var lightBlueImage: Image {
        #if canImport(UIKit)
        let traits = UITraitCollection(userInterfaceStyle: .dark)
        if let uiImage = UIImage(named: assetName, in: nil, compatibleWith: traits) {
            return Image(uiImage: uiImage).renderingMode(.original)
        }
        #endif
        return Image(assetName)
    }
}
