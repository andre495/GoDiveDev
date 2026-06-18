import Foundation

private enum DiveQuantityFormattingConstants: Sendable {
    nonisolated static let feetPerMeter = 3.280839895013123
    /// Same scale as **`FitTankFieldImport`** (**bar → psi**).
    nonisolated static let psiPerBar = 14.5037738007
    nonisolated static let cubicFeetPerLiter = 0.0353146667214888
    nonisolated static let poundsPerKilogram = 2.2046226218
}

/// Formats canonical **`DiveActivity`** / profile values for UI according to **`DiveDisplayUnitSystem`**.
enum DiveQuantityFormatting {

    nonisolated static func depth(meters: Double, system: DiveDisplayUnitSystem) -> String {
        linearMeters(meters, system: system)
    }

    /// Animal size or other length from stored **m** (same conversion as **`depth`**).
    nonisolated static func length(meters: Double, system: DiveDisplayUnitSystem) -> String {
        linearMeters(meters, system: system)
    }

    private nonisolated static func linearMeters(_ meters: Double, system: DiveDisplayUnitSystem) -> String {
        switch system {
        case .metric:
            return String(format: "%.1f m", meters)
        case .imperial:
            let feet = meters * DiveQuantityFormattingConstants.feetPerMeter
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

    /// Diver ballast from stored **kg**; **`nil`** → **—**.
    static func diverWeight(kilograms: Double?, system: DiveDisplayUnitSystem) -> String {
        guard let kilograms, kilograms > 0 else { return "—" }
        switch system {
        case .metric:
            return String(format: "%.1f kg", kilograms)
        case .imperial:
            let pounds = kilograms * DiveQuantityFormattingConstants.poundsPerKilogram
            return String(format: "%.1f lb", pounds)
        }
    }

    /// Cylinder pressure from stored **psi**; **`nil`** → **—**. Metric UI uses **bar**; imperial uses **psi** (whole).
    static func cylinderPressure(fromPSI psi: Double?, system: DiveDisplayUnitSystem) -> String {
        guard let psi else { return "—" }
        switch system {
        case .metric:
            let bar = psi / DiveQuantityFormattingConstants.psiPerBar
            return String(format: "%.1f bar", bar)
        case .imperial:
            return "\(Int(psi.rounded())) psi"
        }
    }

    /// Rated cylinder size from **Settings → Default tank** (or **`specification`** when passed).
    static func tankVolumeDisplay(
        system: DiveDisplayUnitSystem,
        specification: DefaultTankSpecification = DiveActivityTankDefaults.resolvedSpecification()
    ) -> String {
        switch system {
        case .imperial:
            return String(format: "%.0f cu ft", specification.ratedVolumeCubicFeet)
        case .metric:
            return String(format: "%.0f L", specification.ratedVolumeSurfaceLiters.rounded())
        }
    }

    /// **`avgSAC`** stored as **psi/min**; metric UI shows **bar/min**.
    static func surfaceAirConsumption(sacPSIPerMinute: Double?, system: DiveDisplayUnitSystem) -> String? {
        guard let sacPSIPerMinute, sacPSIPerMinute > 0 else { return nil }
        switch system {
        case .metric:
            let barPerMin = sacPSIPerMinute / DiveQuantityFormattingConstants.psiPerBar
            return String(format: "%.1f bar/min", barPerMin)
        case .imperial:
            return String(format: "%.1f psi/min", sacPSIPerMinute)
        }
    }

    /// **`avgRMV`** stored as **L/min**; imperial UI shows **cu ft/min**.
    static func respiratoryMinuteVolume(litersPerMinute: Double?, system: DiveDisplayUnitSystem) -> String? {
        guard let litersPerMinute, litersPerMinute > 0 else { return nil }
        switch system {
        case .metric:
            return String(format: "%.1f L/min", litersPerMinute)
        case .imperial:
            let cfm = litersPerMinute * DiveQuantityFormattingConstants.cubicFeetPerLiter
            return String(format: "%.2f cu ft/min", cfm)
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
