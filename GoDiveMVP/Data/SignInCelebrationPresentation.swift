import CoreGraphics
import Foundation

/// Post–Sign in with Apple celebration overlay (bubble ramp + brand handoff before Home).
enum SignInCelebrationPresentation: Sendable {
    nonisolated static let rootAccessibilityIdentifier = "SignInCelebration.Root"
    nonisolated static let logoAccessibilityIdentifier = "SignInCelebration.Logo"
    nonisolated static let brandAccessibilityIdentifier = "SignInCelebration.Brand"

    /// Bubble rise speed at celebration start (matches standard UI).
    nonisolated static let bubbleSpeedStartMultiplier: CGFloat = 1
    /// Bubble rise speed at celebration peak (2× standard movement).
    nonisolated static let bubbleSpeedEndMultiplier: CGFloat = 2

    /// Total celebration screen time before handing off to Home.
    nonisolated static let durationNanoseconds: UInt64 = 2_400_000_000
    nonisolated static let bubbleSpeedRampDuration: Double = 2.0
    nonisolated static let logoSpringResponse: Double = 0.38
    nonisolated static let logoSpringDamping: Double = 0.78
    nonisolated static let brandFadeDuration: Double = 0.32
    nonisolated static let brandFadeDelay: Double = 0.08

    nonisolated static let homeRevealSpringResponse: Double = 0.55
    nonisolated static let homeRevealSpringDamping: Double = 0.86

    /// Semi-random haptic taps while bubbles ramp (skipped under UI tests).
    nonisolated static let hapticBurstCount = 14
    /// Delay before the first haptic (seconds).
    nonisolated static let hapticBurstStartDelaySeconds: Double = 0.12
    /// Minimum gap between haptic taps (seconds).
    nonisolated static let hapticMinIntervalSeconds: Double = 0.07
    /// Maximum gap between haptic taps (seconds).
    nonisolated static let hapticMaxIntervalSeconds: Double = 0.22

    nonisolated static func shouldPresentCelebration(isUITest: Bool = GoDiveUITestConfiguration.isActive) -> Bool {
        !isUITest
    }

    nonisolated static func shouldPlayCelebrationHaptics(
        isUITest: Bool = GoDiveUITestConfiguration.isActive
    ) -> Bool {
        !isUITest
    }

    /// Deterministic-ish but uneven intervals for a “bubble pop” feel (seeded for tests).
    nonisolated static func hapticIntervalSeconds(index: Int, seed: UInt64 = 0xC3_1EB_B1E) -> Double {
        let mixed = seed &+ UInt64(index) &* 0x9E37_79B9_7F4A_7C15
        let unit = Double(mixed % 1_000) / 1_000.0
        let span = hapticMaxIntervalSeconds - hapticMinIntervalSeconds
        return hapticMinIntervalSeconds + unit * span
    }
}
