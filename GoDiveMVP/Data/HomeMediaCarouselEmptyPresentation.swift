import CoreGraphics
import Foundation

/// Copy and layout rules for the Home hero when the owner has dives but no carousel media yet.
enum HomeMediaCarouselEmptyPresentation: Sendable {

    static let title = "Your highlight reel lives here"
    static let message = "Add photos or videos on a dive in your Logbook — or turn on auto-upload in Settings to pull in matching library media."

    static let frameCount = 3
    static let animationCycleSeconds: Double = 4.8

    /// Nudge copy and ghost frames below geometric center so they sit under the header comfortably.
    static let contentDownshift: CGFloat = 80

    nonisolated static func frameRotationDegrees(index: Int) -> Double {
        switch index {
        case 0: -10
        case 1: 6
        default: -4
        }
    }

    nonisolated static func frameOffsetAmplitude(index: Int) -> CGFloat {
        5 + CGFloat(index) * 2.5
    }

    nonisolated static func framePhaseOffset(index: Int) -> Double {
        Double(index) * 0.55
    }
}
