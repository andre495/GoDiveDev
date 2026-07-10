import CoreGraphics
import Foundation

/// Post–Sign in with Apple celebration overlay (standard bubbles + brand handoff before Home).
enum SignInCelebrationPresentation: Sendable {
    nonisolated static let rootAccessibilityIdentifier = "SignInCelebration.Root"
    nonisolated static let logoAccessibilityIdentifier = "SignInCelebration.Logo"
    nonisolated static let brandAccessibilityIdentifier = "SignInCelebration.Brand"

    /// Total celebration screen time before handing off to Home.
    nonisolated static let durationNanoseconds: UInt64 = 3_000_000_000
    nonisolated static let animationDuration: Double = 3.0
    nonisolated static let logoSpringResponse: Double = 0.38
    nonisolated static let logoSpringDamping: Double = 0.78
    nonisolated static let brandFadeDuration: Double = 0.32
    nonisolated static let brandFadeDelay: Double = 0.08
    /// Fade logo + wordmark before **`completeSignInCelebration`** so Home can appear without a second opacity pass.
    nonisolated static let handoffFadeOutDuration: Double = 0.2
    nonisolated static var handoffFadeOutNanoseconds: UInt64 {
        UInt64(handoffFadeOutDuration * 1_000_000_000)
    }

    /// Semi-random gaps between intermittent haptics (seconds).
    nonisolated static let hapticMinIntervalSeconds: Double = 0.26
    nonisolated static let hapticMaxIntervalSeconds: Double = 0.46
    /// Delay before the first haptic (seconds).
    nonisolated static let hapticBurstStartDelaySeconds: Double = 0.12

    nonisolated static func shouldPresentCelebration(isUITest: Bool = GoDiveUITestConfiguration.isActive) -> Bool {
        !isUITest
    }

    nonisolated static func shouldPlayCelebrationHaptics(
        isUITest: Bool = GoDiveUITestConfiguration.isActive
    ) -> Bool {
        !isUITest
    }

    /// Semi-random wait until the next haptic.
    nonisolated static func hapticWaitIntervalSeconds(
        index: Int,
        seed: UInt64 = 0xC3_1EB_B1E
    ) -> Double {
        let lower = min(hapticMinIntervalSeconds, hapticMaxIntervalSeconds)
        let upper = max(hapticMinIntervalSeconds, hapticMaxIntervalSeconds)
        guard upper > lower else { return lower }
        let unit = hapticRandomUnit(index: index, seed: seed)
        return lower + unit * (upper - lower)
    }

    nonisolated static func hapticImpactIntensity(index: Int) -> CGFloat {
        let base: CGFloat = 0.55
        return index.isMultiple(of: 4) ? min(1, base + 0.2) : base
    }

    nonisolated static func hapticRandomUnit(index: Int, seed: UInt64 = 0xC3_1EB_B1E) -> Double {
        let mixed = seed &+ UInt64(index) &* 0x9E37_79B9_7F4A_7C15
        return Double(mixed % 1_000) / 1_000.0
    }
}
