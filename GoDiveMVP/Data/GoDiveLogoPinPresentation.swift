import SwiftUI

/// Adaptive GoDive pin logo — **`GoDiveLogoPin`** asset catalog (light = dark navy pin, dark = light blue pin).
enum GoDiveLogoPinPresentation: Sendable {
    nonisolated static let assetName = "GoDiveLogoPin"

    /// SwiftUI image — appearance-aware via the asset catalog.
    static var image: Image {
        Image(assetName)
    }
}
