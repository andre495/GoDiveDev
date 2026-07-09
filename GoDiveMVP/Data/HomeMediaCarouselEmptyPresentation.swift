import CoreGraphics
import Foundation

/// Copy and layout rules for the Home hero when the carousel has no media to show.
enum HomeMediaCarouselEmptyPresentation: Sendable {

    enum Context: Sendable {
        /// Owner has no logged dives / activities yet.
        case noLoggedActivities
        /// Owner has dives but no Photos media for the daily carousel yet.
        case noMediaYet
    }

    static let title = title(for: .noMediaYet)
    static let message = message(for: .noMediaYet)

    /// Short line shown under the ghost-frame animation in the Home hero.
    nonisolated static func headline(for context: Context) -> String {
        switch context {
        case .noLoggedActivities:
            "Log Your First Dive"
        case .noMediaYet:
            "Add Media to your Dives"
        }
    }

    nonisolated static func title(for context: Context) -> String {
        headline(for: context)
    }

    nonisolated static func message(for context: Context) -> String {
        switch context {
        case .noLoggedActivities:
            "Import a dive file or add an activity from the Logbook to unlock lifetime stats and your highlight reel."
        case .noMediaYet:
            "Add photos or videos on a dive in your Logbook — or turn on auto-upload in Settings to pull in matching library media."
        }
    }

    static let frameCount = 3
    static let animationCycleSeconds: Double = 4.8

    /// Nudge ghost frames below geometric center so they sit under the header comfortably.
    static let contentDownshift: CGFloat = 48

    /// Extra lift above the carousel chrome band so the CTA sits closer to the ghost-frame animation.
    static let ctaBottomLift: CGFloat = 96

    /// Bottom inset for the empty-hero CTA — carousel chrome band plus a small lift.
    static var ctaBottomInset: CGFloat {
        HomeOverviewLayout.panelOverlap - AppTheme.Spacing.md + ctaBottomLift
    }

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
