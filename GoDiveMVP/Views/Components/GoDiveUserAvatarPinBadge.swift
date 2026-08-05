import SwiftUI

/// Appearance-aware GoDive pin for the lower-right corner of a buddy / friend avatar circle.
struct GoDiveUserAvatarPinBadge: View {
    let avatarDiameter: CGFloat

    private var sideLength: CGFloat {
        GoDiveUserAvatarPinPresentation.pinSideLength(forAvatarDiameter: avatarDiameter)
    }

    private var edgeOffset: CGSize {
        GoDiveUserAvatarPinPresentation.pinEdgeOverlapOffset(forAvatarDiameter: avatarDiameter)
    }

    var body: some View {
        GoDiveUserAvatarPinPresentation.image
            .resizable()
            .scaledToFit()
            .frame(width: sideLength, height: sideLength)
            .offset(x: edgeOffset.width, y: edgeOffset.height)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Overlays the GoDive user pin on the lower-right rim of an avatar (outside `clipShape`).
    @ViewBuilder
    func goDiveUserAvatarPin(shows: Bool, avatarDiameter: CGFloat) -> some View {
        if shows {
            overlay(alignment: .bottomTrailing) {
                GoDiveUserAvatarPinBadge(avatarDiameter: avatarDiameter)
            }
        } else {
            self
        }
    }
}
