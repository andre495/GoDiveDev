import Foundation

/// Parses user-entered quantities for dive field editors (canonical storage units).
enum DiveActivityFieldValueParsing: Sendable {
    private static let feetPerMeter = 3.280839895013123
    private static let psiPerBar = 14.5037738007

    static func parseDouble(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed
            .replacingOccurrences(of: ",", with: ".")
            .filter { "0123456789.-".contains($0) }
        return Double(normalized)
    }

    static func parseInt(_ text: String) -> Int? {
        guard let value = parseDouble(text) else { return nil }
        return Int(value.rounded())
    }

    static func parseDepthMeters(_ text: String, displayUnits: DiveDisplayUnitSystem) -> Double? {
        guard let raw = parseDouble(text) else { return nil }
        switch displayUnits {
        case .metric: return raw
        case .imperial: return raw / feetPerMeter
        }
    }

    static func parsePressurePSI(_ text: String, displayUnits: DiveDisplayUnitSystem) -> Double? {
        guard let raw = parseDouble(text) else { return nil }
        switch displayUnits {
        case .metric: return raw * psiPerBar
        case .imperial: return raw
        }
    }

    static func parseWaterTempCelsius(_ text: String, displayUnits: DiveDisplayUnitSystem) -> Double? {
        guard let raw = parseDouble(text) else { return nil }
        switch displayUnits {
        case .metric: return raw
        case .imperial: return (raw - 32.0) * 5.0 / 9.0
        }
    }

    static func parseAscentRateMetersPerSecond(_ text: String, displayUnits: DiveDisplayUnitSystem) -> Double? {
        guard let raw = parseDouble(text) else { return nil }
        switch displayUnits {
        case .metric: return raw
        case .imperial: return raw / (feetPerMeter * 60.0)
        }
    }

    static func parseSACPSIPerMinute(_ text: String, displayUnits: DiveDisplayUnitSystem) -> Double? {
        guard let raw = parseDouble(text) else { return nil }
        switch displayUnits {
        case .metric: return raw * psiPerBar
        case .imperial: return raw
        }
    }

    static func parseRMVLitersPerMinute(_ text: String, displayUnits: DiveDisplayUnitSystem) -> Double? {
        guard let raw = parseDouble(text) else { return nil }
        let cubicFeetPerLiter = 0.0353146667214888
        switch displayUnits {
        case .metric: return raw
        case .imperial: return raw / cubicFeetPerLiter
        }
    }

    static func parseCoordinate(latitudeText: String, longitudeText: String) -> DiveCoordinate? {
        guard let lat = parseDouble(latitudeText), let lon = parseDouble(longitudeText) else { return nil }
        let candidate = DiveCoordinate(latitude: lat, longitude: lon)
        return DiveMapCoordinateResolver.isUsable(candidate) ? candidate : nil
    }
}
