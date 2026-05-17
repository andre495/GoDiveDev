import Foundation

/// Formats canonical **`DiveActivity`** / profile values for UI according to **`DiveDisplayUnitSystem`**.
enum DiveQuantityFormatting {

    private static let feetPerMeter = 3.280839895013123
    /// Same scale as **`FitTankFieldImport`** (**bar → psi**).
    private static let psiPerBar = 14.5037738007
    private static let cubicFeetPerLiter = 0.0353146667214888

    static func depth(meters: Double, system: DiveDisplayUnitSystem) -> String {
        switch system {
        case .metric:
            return String(format: "%.1f m", meters)
        case .imperial:
            let feet = meters * feetPerMeter
            return String(format: "%.1f ft", feet)
        }
    }

    /// Water temperature from stored **°C**; **`nil`** → **—**.
    static func waterTemperature(celsius: Double?, system: DiveDisplayUnitSystem) -> String {
        guard let celsius else { return "—" }
        switch system {
        case .metric:
            return String(format: "%.1f °C", celsius)
        case .imperial:
            let fahrenheit = celsius * 9.0 / 5.0 + 32.0
            return String(format: "%.1f °F", fahrenheit)
        }
    }

    /// Cylinder pressure from stored **psi**; **`nil`** → **—**. Metric UI uses **bar**; imperial uses **psi** (whole).
    static func cylinderPressure(fromPSI psi: Double?, system: DiveDisplayUnitSystem) -> String {
        guard let psi else { return "—" }
        switch system {
        case .metric:
            let bar = psi / psiPerBar
            return String(format: "%.1f bar", bar)
        case .imperial:
            return "\(Int(psi.rounded())) psi"
        }
    }

    /// **`tankVolumeDescription`** is import text (often **`… L …`**). Metric shows the stored string; imperial prefers **cu ft** when a leading **`… L`** segment can be parsed.
    static func tankVolumeDisplay(storedDescription: String?, system: DiveDisplayUnitSystem) -> String {
        guard let raw = storedDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "—"
        }
        switch system {
        case .metric:
            return raw
        case .imperial:
            guard let liters = firstLitersValue(in: raw) else { return raw }
            let cubicFeet = liters * cubicFeetPerLiter
            return String(format: "%.1f cu ft", cubicFeet)
        }
    }

    /// Parses the first **`number` + `L`** segment (e.g. **`80 L (0.080 m³)`** → **80**). Exposed for tests.
    static func firstLitersValue(in description: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)\s*L"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let full = NSRange(location: 0, length: (description as NSString).length)
        guard let match = regex.firstMatch(in: description, options: [], range: full),
              match.numberOfRanges >= 2,
              let capture = Range(match.range(at: 1), in: description) else { return nil }
        return Double(description[capture])
    }
}
