import Foundation

/// Offline fallback when **`MKReverseGeocodingRequest`** / **`MKLocalSearch`** is unavailable (decode + import tail).
enum DiveSiteGeographyTimeZoneInference: Sendable {

    /// Hours east of UTC (UDDF float) at **`instant`** for dive-site coordinates, or **`nil`** when unknown.
    nonisolated static func uddfHoursFromUTC(
        latitude: Double,
        longitude: Double,
        at instant: Date
    ) -> Double? {
        guard let identifier = ianaTimeZoneIdentifier(latitude: latitude, longitude: longitude),
              let timeZone = TimeZone(identifier: identifier)
        else { return nil }
        return Double(timeZone.secondsFromGMT(for: instant)) / 3600.0
    }

    /// Coarse IANA mapping for common dive regions (offline; no reverse geocode).
    nonisolated static func ianaTimeZoneIdentifier(latitude: Double, longitude: Double) -> String? {
        if caribbeanABC.contains(latitude: latitude, longitude: longitude) {
            return "America/Kralendijk"
        }
        if floridaKeys.contains(latitude: latitude, longitude: longitude) {
            return "America/New_York"
        }
        if hawaii.contains(latitude: latitude, longitude: longitude) {
            return "Pacific/Honolulu"
        }
        if redSea.contains(latitude: latitude, longitude: longitude) {
            return "Asia/Riyadh"
        }
        if greatBarrierReef.contains(latitude: latitude, longitude: longitude) {
            return "Australia/Brisbane"
        }
        if mexicoCaribbean.contains(latitude: latitude, longitude: longitude) {
            return "America/Cancun"
        }
        if belize.contains(latitude: latitude, longitude: longitude) {
            return "America/Belize"
        }
        if usMountainWest.contains(latitude: latitude, longitude: longitude) {
            return "America/Denver"
        }
        return nil
    }

    /// When MacDive omits site coordinates, use **`geography/location`** (e.g. "Cozumel").
    nonisolated static func uddfHoursFromLocationName(_ locationName: String?, at instant: Date) -> Double? {
        let normalized = locationName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard !normalized.isEmpty else { return nil }

        let identifier: String?
        if normalized.contains("cozumel") || normalized.contains("playa del carmen") || normalized.contains("tulum") {
            identifier = "America/Cancun"
        } else if normalized.contains("belize") {
            identifier = "America/Belize"
        } else if normalized.contains("bonaire") {
            identifier = "America/Kralendijk"
        } else if normalized.contains("utah") || normalized.contains("colorado") {
            identifier = "America/Denver"
        } else {
            identifier = nil
        }

        guard let identifier, let timeZone = TimeZone(identifier: identifier) else { return nil }
        return Double(timeZone.secondsFromGMT(for: instant)) / 3600.0
    }

    private enum caribbeanABC {
        nonisolated static func contains(latitude: Double, longitude: Double) -> Bool {
            latitude >= 10.0 && latitude <= 22.0 && longitude >= -72.0 && longitude <= -62.0
        }
    }

    private enum floridaKeys {
        nonisolated static func contains(latitude: Double, longitude: Double) -> Bool {
            latitude >= 24.0 && latitude <= 31.0 && longitude >= -83.0 && longitude <= -79.0
        }
    }

    private enum hawaii {
        nonisolated static func contains(latitude: Double, longitude: Double) -> Bool {
            latitude >= 18.0 && latitude <= 23.0 && longitude >= -161.0 && longitude <= -154.0
        }
    }

    private enum redSea {
        nonisolated static func contains(latitude: Double, longitude: Double) -> Bool {
            latitude >= 20.0 && latitude <= 30.0 && longitude >= 34.0 && longitude <= 45.0
        }
    }

    private enum greatBarrierReef {
        nonisolated static func contains(latitude: Double, longitude: Double) -> Bool {
            latitude >= -24.0 && latitude <= -10.0 && longitude >= 142.0 && longitude <= 154.0
        }
    }

    /// Cozumel / Riviera Maya (MacDive exports often use lon ≈ −87).
    private enum mexicoCaribbean {
        nonisolated static func contains(latitude: Double, longitude: Double) -> Bool {
            latitude >= 18.0 && latitude <= 21.5 && longitude >= -89.5 && longitude <= -86.0
        }
    }

    private enum belize {
        nonisolated static func contains(latitude: Double, longitude: Double) -> Bool {
            latitude >= 15.0 && latitude <= 18.5 && longitude >= -89.5 && longitude <= -86.5
        }
    }

    /// Inland US dive sites (e.g. Homestead Crater UT, Colorado quarry).
    private enum usMountainWest {
        nonisolated static func contains(latitude: Double, longitude: Double) -> Bool {
            latitude >= 37.0 && latitude <= 42.0 && longitude >= -115.0 && longitude <= -104.0
        }
    }
}
