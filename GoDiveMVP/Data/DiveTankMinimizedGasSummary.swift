import Foundation

/// Animated minimized **PSI used** tally (number + unit suffix).
struct MinimizedGasConsumedTally: Equatable, Sendable {
    /// Drives **`.contentTransition(.numericText())`** during the tank **minimized** entrance.
    var numericAnimationValue: Double
    var pressureValueText: String
    var unitSuffix: String
}

/// Copy and math for the minimized tank-hero gas readout (beside the small cylinder).
enum DiveTankMinimizedGasSummary: Sendable {

    /// **`start - end`** in **psi** when both dive-level pressures exist.
    nonisolated static func psiConsumedPSI(startPSI: Double?, endPSI: Double?) -> Double? {
        guard let startPSI, let endPSI, startPSI > 0 else { return nil }
        return max(0, startPSI - endPSI)
    }

    /// Count-up display for **PSI used** while **`revealProgress`** runs **0 → 1**.
    nonisolated static func minimizedGasConsumedTally(
        totalConsumedPSI: Double,
        revealProgress: CGFloat,
        system: DiveDisplayUnitSystem
    ) -> MinimizedGasConsumedTally {
        let animatedPSI = DiveTankOverviewHeroPresentation.displayedPsiConsumed(
            consumedPSI: totalConsumedPSI,
            revealProgress: revealProgress
        )
        switch system {
        case .imperial:
            let count = Int(floor(animatedPSI))
            return MinimizedGasConsumedTally(
                numericAnimationValue: Double(count),
                pressureValueText: Self.groupedInteger(count),
                unitSuffix: " psi"
            )
        case .metric:
            let bar = DiveQuantityFormatting.bar(fromPSI: animatedPSI)
            let tenths = Int(floor(bar * 10))
            let displayBar = Double(tenths) / 10
            return MinimizedGasConsumedTally(
                numericAnimationValue: displayBar,
                pressureValueText: String(format: "%.1f", displayBar),
                unitSuffix: " bar"
            )
        }
    }

    nonisolated static func usedLine(formattedConsumed: String) -> String {
        "\(formattedConsumed) used."
    }

    private nonisolated static func groupedInteger(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    nonisolated static let sacRateLabel = "SAC:"
    nonisolated static let rmvRateLabel = "RMV:"

    nonisolated static func sacRateLine(formattedRate: String) -> String {
        "\(sacRateLabel) \(formattedRate)"
    }

    nonisolated static func rmvRateLine(formattedRate: String) -> String {
        "\(rmvRateLabel) \(formattedRate)"
    }
}
