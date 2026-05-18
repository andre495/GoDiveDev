import Foundation

/// Copy and math for the minimized tank-hero gas readout (beside the small cylinder).
enum DiveTankMinimizedGasSummary: Sendable {

    /// **`start - end`** in **psi** when both dive-level pressures exist.
    nonisolated static func psiConsumedPSI(startPSI: Double?, endPSI: Double?) -> Double? {
        guard let startPSI, let endPSI, startPSI > 0 else { return nil }
        return max(0, startPSI - endPSI)
    }

    nonisolated static func usedLine(formattedConsumed: String) -> String {
        "\(formattedConsumed) used."
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
