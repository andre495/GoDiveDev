import CoreGraphics
import Foundation
import SwiftUI

/// Light-blue GoDive pin badge sized for the lower-right corner of buddy / friend avatars.
enum GoDiveUserAvatarPinPresentation: Sendable {
    /// Catalog asset from Desktop **`GoDiveMVP_icon/pin simple DARK.png`**.
    nonisolated static let assetName = "GoDiveUserAvatarPin"

    nonisolated static let accessibilityLabel = BuddiesListPresentation.friendBadgeAccessibilityLabel

    /// Pin side length as a fraction of avatar diameter — ~2× prior badge scale.
    nonisolated static func pinSideLength(forAvatarDiameter diameter: CGFloat) -> CGFloat {
        max(28, min(56, diameter * 0.76))
    }

    /// Outward offset from bottom-trailing so the pin straddles the avatar rim.
    nonisolated static func pinEdgeOverlapOffset(forAvatarDiameter diameter: CGFloat) -> CGSize {
        let side = pinSideLength(forAvatarDiameter: diameter)
        let outward = side * 0.5
        return CGSize(width: outward, height: outward)
    }

    nonisolated static func showsGoDiveUserPin(isFriend: Bool) -> Bool {
        BuddiesListPresentation.showsGoDiveUserPin(isFriend: isFriend)
    }

    static var image: Image {
        Image(assetName).renderingMode(.original)
    }
}
