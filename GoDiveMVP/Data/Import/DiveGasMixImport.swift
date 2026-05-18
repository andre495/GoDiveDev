import Foundation

/// Normalizes imported gas mix values onto **`DiveActivity.oxygenMix`** (percent) and **`DiveActivity.gasType`**.
enum DiveGasMixImport {

    /// UDDF **`<o2>`** is usually a **fraction** (e.g. `0.30` → 30%); values already above 1 are treated as percent.
    static func oxygenPercent(fromUddfO2 raw: Double) -> Double {
        raw > 1.0 ? raw : raw * 100.0
    }

    /// FIT **`DiveGasMesg.oxygen_content`** is already an integer **percent** (e.g. 32).
    static func oxygenPercent(fromFitOxygenContent content: Float) -> Double {
        Double(content)
    }

    /// **Air** at ~21% O₂; otherwise **Nitrox**.
    static func gasType(forOxygenPercent percent: Double) -> String {
        abs(percent - 21.0) < 0.01 ? "Air" : "Nitrox"
    }

    static func resolved(fromOxygenPercent percent: Double) -> (oxygenMix: Double, gasType: String) {
        (percent, gasType(forOxygenPercent: percent))
    }

    static func resolved(fromUddfO2 raw: Double) -> (oxygenMix: Double, gasType: String) {
        resolved(fromOxygenPercent: oxygenPercent(fromUddfO2: raw))
    }

    static func resolved(fromFitOxygenContent content: Float) -> (oxygenMix: Double, gasType: String) {
        resolved(fromOxygenPercent: oxygenPercent(fromFitOxygenContent: content))
    }

    static let tankHeroNoGasSpecifiedLabel = "No gas specified"

    /// Default O₂ band when **`oxygenMix`** is unknown (**air**, 21%).
    static let defaultOxygenMixPercent: Double = 21

    /// Fraction of the visible gas column drawn as yellow (bottom band); **`oxygenMix`** percent or **21%** default.
    static func tankYellowFillFraction(oxygenMixPercent: Double?) -> CGFloat {
        let pct = oxygenMixPercent ?? defaultOxygenMixPercent
        return CGFloat(min(100, max(0, pct)) / 100.0)
    }

    /// Tank hero label: **`gasType`** + **`oxygenMix`** (percent), or **`tankHeroNoGasSpecifiedLabel`**.
    static func tankHeroLabel(gasType: String?, oxygenMix: Double?) -> String {
        guard let gasType, let oxygenMix else { return tankHeroNoGasSpecifiedLabel }
        let trimmed = gasType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return tankHeroNoGasSpecifiedLabel }
        let pct = Int(oxygenMix.rounded())
        return "\(trimmed) \(pct)%"
    }
}
