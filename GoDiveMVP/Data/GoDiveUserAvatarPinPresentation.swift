import CoreGraphics
import Foundation
import SwiftUI

/// Adaptive GoDive pin badge sized for the lower-right corner of buddy / friend avatars.
enum GoDiveUserAvatarPinPresentation: Sendable {
    /// Catalog asset — light = **`pin simple LIGHT`**, dark = **`pin simple DARK`** (Desktop **`GoDiveMVP_icon`**).
    nonisolated static let assetName = "GoDiveUserAvatarPin"

    nonisolated static let accessibilityLabel = BuddiesListPresentation.friendBadgeAccessibilityLabel

    /// Pin side length as a fraction of avatar diameter — ~2× prior badge scale.
    nonisolated static func pinSideLength(forAvatarDiameter diameter: CGFloat) -> CGFloat {
        max(28, min(56, diameter * 0.76))
    }

    /// Fraction of pin side length pushed past the bottom-trailing rim (smaller = more avatar overlap).
    nonisolated static let pinEdgeOutwardFraction: CGFloat = 0.32

    /// Outward offset from bottom-trailing so the pin straddles the avatar rim.
    nonisolated static func pinEdgeOverlapOffset(forAvatarDiameter diameter: CGFloat) -> CGSize {
        let side = pinSideLength(forAvatarDiameter: diameter)
        let outward = side * pinEdgeOutwardFraction
        return CGSize(width: outward, height: outward)
    }

    nonisolated static func showsGoDiveUserPin(isFriend: Bool) -> Bool {
        BuddiesListPresentation.showsGoDiveUserPin(isFriend: isFriend)
    }

    /// SwiftUI image — appearance-aware via the asset catalog.
    static var image: Image {
        Image(assetName).renderingMode(.original)
    }
}
