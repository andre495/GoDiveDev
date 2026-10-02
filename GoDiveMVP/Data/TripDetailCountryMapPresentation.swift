import Foundation

/// Country-level hero map framing when a trip has destinations but no site pins yet.
enum TripDetailCountryMapPresentation: Sendable {

    /// Combined-country frame is abandoned when the union is wider than this (US + China).
    nonisolated static let maxCombinedLatitudeDelta: Double = 50
    nonisolated static let maxCombinedLongitudeDelta: Double = 80
    /// Geographic box is the country itself; hero padding supplies visible margin.
    nonisolated static let fittingPaddingMultiplier: Double = 1.0
    nonisolated static let minimumSpanDegrees: Double = 0.02

    nonisolated private struct CountryMapBox: Equatable, Sendable {
        let minLatitude: Double
        let maxLatitude: Double
        let minLongitude: Double
        let maxLongitude: Double
    }

    nonisolated private struct ResolvedCountry: Equatable, Sendable {
        let name: String
        let isoRegionCode: String
        let box: CountryMapBox
    }

    /// Upcoming trips, or any trip with no linked activities, use selected countries when there are no site pins.
    nonisolated static func shouldUseCountryFocus(
        isUpcoming: Bool,
        linkedActivityCount: Int,
        hasMapPins: Bool
    ) -> Bool {
        guard !hasMapPins else { return false }
        return isUpcoming || linkedActivityCount == 0
    }

    nonisolated static func focusRegion(
        countries: [String],
        isUpcoming: Bool,
        linkedActivityCount: Int,
        hasMapPins: Bool
    ) -> DiveLocationMapRegionSpec? {
        guard shouldUseCountryFocus(
            isUpcoming: isUpcoming,
            linkedActivityCount: linkedActivityCount,
            hasMapPins: hasMapPins
        ) else { return nil }
        return fittingRegion(countries: countries)
    }

    nonisolated static func fittingRegion(countries: [String]) -> DiveLocationMapRegionSpec? {
        let resolved = resolvedCountries(in: countries)
        guard let first = resolved.first else { return nil }
        if resolved.count == 1 {
            return regionSpec(for: first.box)
        }

        let union = unionBox(resolved.map(\.box))
        if isTooSpread(union) {
            return regionSpec(for: first.box)
        }
        return regionSpec(for: union)
    }

    nonisolated static func focusedCountryNames(from countries: [String]) -> [String] {
        let resolved = resolvedCountries(in: countries)
        guard let first = resolved.first else { return [] }
        if resolved.count == 1 {
            return [first.name]
        }
        let union = unionBox(resolved.map(\.box))
        if isTooSpread(union) {
            return [first.name]
        }
        return resolved.map(\.name)
    }

    /// Approximate Google Maps zoom so a provisional camera still shows the country (not the world).
    nonisolated static func approximateGoogleZoomLevel(for region: DiveLocationMapRegionSpec) -> Float {
        let span = max(region.latitudeDelta, region.longitudeDelta, minimumSpanDegrees)
        let raw = log2(360.0 / span)
        return Float(min(12, max(3, raw)))
    }

    private nonisolated static func resolvedCountries(in countries: [String]) -> [ResolvedCountry] {
        var seenCodes = Set<String>()
        var resolved: [ResolvedCountry] = []
        for raw in countries {
            let name = DiveSiteCountryPresentation.canonicalDisplayName(for: raw)
            guard !name.isEmpty else { continue }
            guard let code = DiveSiteCountryPresentation.isoRegionCode(forCountryName: name) else {
                continue
            }
            let iso = code.uppercased()
            guard seenCodes.insert(iso).inserted else { continue }
            guard let box = boxByISORegionCode[iso] else { continue }
            resolved.append(ResolvedCountry(name: name, isoRegionCode: iso, box: box))
        }
        return resolved
    }

    private nonisolated static func isTooSpread(_ box: CountryMapBox) -> Bool {
        (box.maxLatitude - box.minLatitude) > maxCombinedLatitudeDelta
            || (box.maxLongitude - box.minLongitude) > maxCombinedLongitudeDelta
    }

    private nonisolated static func unionBox(_ boxes: [CountryMapBox]) -> CountryMapBox {
        var minLat = boxes[0].minLatitude
        var maxLat = boxes[0].maxLatitude
        var minLon = boxes[0].minLongitude
        var maxLon = boxes[0].maxLongitude
        for box in boxes.dropFirst() {
            minLat = min(minLat, box.minLatitude)
            maxLat = max(maxLat, box.maxLatitude)
            minLon = min(minLon, box.minLongitude)
            maxLon = max(maxLon, box.maxLongitude)
        }
        return CountryMapBox(
            minLatitude: minLat,
            maxLatitude: maxLat,
            minLongitude: minLon,
            maxLongitude: maxLon
        )
    }

    private nonisolated static func regionSpec(for box: CountryMapBox) -> DiveLocationMapRegionSpec {
        let latSpan = max(box.maxLatitude - box.minLatitude, 0)
        let lonSpan = max(box.maxLongitude - box.minLongitude, 0)
        return DiveLocationMapRegionSpec(
            centerLatitude: (box.minLatitude + box.maxLatitude) / 2,
            centerLongitude: (box.minLongitude + box.maxLongitude) / 2,
            latitudeDelta: max(latSpan * fittingPaddingMultiplier, minimumSpanDegrees),
            longitudeDelta: max(lonSpan * fittingPaddingMultiplier, minimumSpanDegrees)
        )
    }

    /// Primary-landmass boxes (ISO 3166-1 alpha-2). Distant overseas territories are omitted.
    private nonisolated static let boxByISORegionCode: [String: CountryMapBox] = [
        "AD": .init(minLatitude: 42.43, maxLatitude: 42.66, minLongitude: 1.41, maxLongitude: 1.79),
        "AE": .init(minLatitude: 22.63, maxLatitude: 26.08, minLongitude: 51.58, maxLongitude: 56.40),
        "AG": .init(minLatitude: 16.93, maxLatitude: 17.73, minLongitude: -61.91, maxLongitude: -61.67),
        "AR": .init(minLatitude: -55.06, maxLatitude: -21.78, minLongitude: -73.58, maxLongitude: -53.64),
        "AT": .init(minLatitude: 46.37, maxLatitude: 49.02, minLongitude: 9.53, maxLongitude: 17.16),
        "AU": .init(minLatitude: -43.64, maxLatitude: -10.06, minLongitude: 113.34, maxLongitude: 153.57),
        "AW": .init(minLatitude: 12.41, maxLatitude: 12.63, minLongitude: -70.06, maxLongitude: -69.87),
        "BB": .init(minLatitude: 13.04, maxLatitude: 13.34, minLongitude: -59.65, maxLongitude: -59.42),
        "BE": .init(minLatitude: 49.50, maxLatitude: 51.51, minLongitude: 2.54, maxLongitude: 6.41),
        "BG": .init(minLatitude: 41.24, maxLatitude: 44.22, minLongitude: 22.36, maxLongitude: 28.61),
        "BH": .init(minLatitude: 25.80, maxLatitude: 26.29, minLongitude: 50.39, maxLongitude: 50.82),
        "BM": .init(minLatitude: 32.24, maxLatitude: 32.39, minLongitude: -64.89, maxLongitude: -64.65),
        "BQ": .init(minLatitude: 12.02, maxLatitude: 17.65, minLongitude: -68.42, maxLongitude: -62.95),
        "BR": .init(minLatitude: -33.75, maxLatitude: 5.27, minLongitude: -73.99, maxLongitude: -34.79),
        "BS": .init(minLatitude: 20.91, maxLatitude: 27.26, minLongitude: -80.74, maxLongitude: -72.74),
        "BZ": .init(minLatitude: 15.89, maxLatitude: 18.50, minLongitude: -89.23, maxLongitude: -87.48),
        "CA": .init(minLatitude: 41.68, maxLatitude: 83.11, minLongitude: -141.00, maxLongitude: -52.62),
        "CH": .init(minLatitude: 45.82, maxLatitude: 47.81, minLongitude: 5.96, maxLongitude: 10.49),
        "CL": .init(minLatitude: -55.98, maxLatitude: -17.51, minLongitude: -75.64, maxLongitude: -66.42),
        "CN": .init(minLatitude: 18.16, maxLatitude: 53.56, minLongitude: 73.50, maxLongitude: 134.77),
        "CO": .init(minLatitude: -4.23, maxLatitude: 13.39, minLongitude: -81.73, maxLongitude: -66.87),
        "CR": .init(minLatitude: 8.03, maxLatitude: 11.22, minLongitude: -85.95, maxLongitude: -82.55),
        "CU": .init(minLatitude: 19.83, maxLatitude: 23.28, minLongitude: -84.95, maxLongitude: -74.13),
        "CW": .init(minLatitude: 12.04, maxLatitude: 12.39, minLongitude: -69.16, maxLongitude: -68.75),
        "CY": .init(minLatitude: 34.57, maxLatitude: 35.70, minLongitude: 32.27, maxLongitude: 34.59),
        "CZ": .init(minLatitude: 48.55, maxLatitude: 51.06, minLongitude: 12.09, maxLongitude: 18.86),
        "DE": .init(minLatitude: 47.27, maxLatitude: 55.06, minLongitude: 5.87, maxLongitude: 15.04),
        "DK": .init(minLatitude: 54.56, maxLatitude: 57.75, minLongitude: 8.08, maxLongitude: 15.16),
        "DO": .init(minLatitude: 17.54, maxLatitude: 19.93, minLongitude: -72.00, maxLongitude: -68.32),
        "EC": .init(minLatitude: -5.00, maxLatitude: 1.68, minLongitude: -92.01, maxLongitude: -75.19),
        "EG": .init(minLatitude: 22.00, maxLatitude: 31.67, minLongitude: 24.70, maxLongitude: 36.89),
        "ES": .init(minLatitude: 36.00, maxLatitude: 43.79, minLongitude: -9.30, maxLongitude: 3.32),
        "FI": .init(minLatitude: 59.81, maxLatitude: 70.09, minLongitude: 20.65, maxLongitude: 31.59),
        "FJ": .init(minLatitude: -21.94, maxLatitude: -12.48, minLongitude: 177.00, maxLongitude: 180.00),
        "FM": .init(minLatitude: 5.26, maxLatitude: 9.59, minLongitude: 138.06, maxLongitude: 163.04),
        "FR": .init(minLatitude: 42.33, maxLatitude: 51.09, minLongitude: -5.14, maxLongitude: 9.56),
        "GB": .init(minLatitude: 49.96, maxLatitude: 58.64, minLongitude: -8.18, maxLongitude: 1.77),
        "GD": .init(minLatitude: 11.99, maxLatitude: 12.32, minLongitude: -61.80, maxLongitude: -61.58),
        "GR": .init(minLatitude: 34.80, maxLatitude: 41.75, minLongitude: 19.37, maxLongitude: 29.65),
        "GT": .init(minLatitude: 13.74, maxLatitude: 17.82, minLongitude: -92.24, maxLongitude: -88.23),
        "GU": .init(minLatitude: 13.23, maxLatitude: 13.65, minLongitude: 144.62, maxLongitude: 144.96),
        "HN": .init(minLatitude: 12.98, maxLatitude: 16.51, minLongitude: -89.35, maxLongitude: -83.13),
        "HR": .init(minLatitude: 42.40, maxLatitude: 46.55, minLongitude: 13.49, maxLongitude: 19.43),
        "HT": .init(minLatitude: 18.02, maxLatitude: 20.09, minLongitude: -74.48, maxLongitude: -71.62),
        "ID": .init(minLatitude: -11.00, maxLatitude: 6.08, minLongitude: 95.01, maxLongitude: 141.02),
        "IE": .init(minLatitude: 51.42, maxLatitude: 55.39, minLongitude: -10.48, maxLongitude: -6.00),
        "IL": .init(minLatitude: 29.50, maxLatitude: 33.34, minLongitude: 34.27, maxLongitude: 35.90),
        "IN": .init(minLatitude: 6.75, maxLatitude: 35.67, minLongitude: 68.18, maxLongitude: 97.40),
        "IS": .init(minLatitude: 63.39, maxLatitude: 66.54, minLongitude: -24.55, maxLongitude: -13.50),
        "IT": .init(minLatitude: 36.64, maxLatitude: 47.09, minLongitude: 6.63, maxLongitude: 18.52),
        "JM": .init(minLatitude: 17.70, maxLatitude: 18.53, minLongitude: -78.37, maxLongitude: -76.18),
        "JP": .init(minLatitude: 24.25, maxLatitude: 45.52, minLongitude: 122.93, maxLongitude: 145.82),
        "KE": .init(minLatitude: -4.68, maxLatitude: 4.62, minLongitude: 33.91, maxLongitude: 41.90),
        "KH": .init(minLatitude: 10.41, maxLatitude: 14.69, minLongitude: 102.35, maxLongitude: 107.63),
        "KR": .init(minLatitude: 33.19, maxLatitude: 38.61, minLongitude: 125.89, maxLongitude: 129.58),
        "KY": .init(minLatitude: 19.26, maxLatitude: 19.76, minLongitude: -81.42, maxLongitude: -79.73),
        "LC": .init(minLatitude: 13.70, maxLatitude: 14.10, minLongitude: -61.08, maxLongitude: -60.87),
        "LK": .init(minLatitude: 5.92, maxLatitude: 9.84, minLongitude: 79.65, maxLongitude: 81.88),
        "MH": .init(minLatitude: 4.57, maxLatitude: 14.62, minLongitude: 160.79, maxLongitude: 172.09),
        "MT": .init(minLatitude: 35.80, maxLatitude: 36.08, minLongitude: 14.18, maxLongitude: 14.58),
        "MU": .init(minLatitude: -20.53, maxLatitude: -19.98, minLongitude: 57.31, maxLongitude: 57.80),
        "MV": .init(minLatitude: -0.69, maxLatitude: 7.10, minLongitude: 72.69, maxLongitude: 73.64),
        "MX": .init(minLatitude: 14.54, maxLatitude: 32.72, minLongitude: -118.37, maxLongitude: -86.81),
        "MY": .init(minLatitude: 0.85, maxLatitude: 7.36, minLongitude: 99.64, maxLongitude: 119.27),
        "NC": .init(minLatitude: -22.70, maxLatitude: -19.55, minLongitude: 163.56, maxLongitude: 168.13),
        "NL": .init(minLatitude: 50.75, maxLatitude: 53.55, minLongitude: 3.36, maxLongitude: 7.23),
        "NO": .init(minLatitude: 57.98, maxLatitude: 71.18, minLongitude: 4.65, maxLongitude: 31.08),
        "NZ": .init(minLatitude: -47.29, maxLatitude: -34.39, minLongitude: 166.51, maxLongitude: 178.52),
        "OM": .init(minLatitude: 16.65, maxLatitude: 26.39, minLongitude: 52.00, maxLongitude: 59.84),
        "PA": .init(minLatitude: 7.20, maxLatitude: 9.62, minLongitude: -83.05, maxLongitude: -77.16),
        "PE": .init(minLatitude: -18.35, maxLatitude: -0.04, minLongitude: -81.33, maxLongitude: -68.67),
        "PF": .init(minLatitude: -27.65, maxLatitude: -7.90, minLongitude: -152.48, maxLongitude: -134.93),
        "PG": .init(minLatitude: -11.66, maxLatitude: -1.32, minLongitude: 140.84, maxLongitude: 155.96),
        "PH": .init(minLatitude: 4.64, maxLatitude: 21.12, minLongitude: 116.93, maxLongitude: 126.60),
        "PL": .init(minLatitude: 49.00, maxLatitude: 54.84, minLongitude: 14.12, maxLongitude: 24.15),
        "PR": .init(minLatitude: 17.88, maxLatitude: 18.52, minLongitude: -67.27, maxLongitude: -65.59),
        "PT": .init(minLatitude: 36.96, maxLatitude: 42.15, minLongitude: -9.50, maxLongitude: -6.19),
        "PW": .init(minLatitude: 6.89, maxLatitude: 8.09, minLongitude: 134.12, maxLongitude: 134.77),
        "QA": .init(minLatitude: 24.48, maxLatitude: 26.18, minLongitude: 50.75, maxLongitude: 51.61),
        "RE": .init(minLatitude: -21.39, maxLatitude: -20.87, minLongitude: 55.22, maxLongitude: 55.84),
        "SA": .init(minLatitude: 16.35, maxLatitude: 32.15, minLongitude: 34.50, maxLongitude: 55.67),
        "SB": .init(minLatitude: -11.85, maxLatitude: -6.59, minLongitude: 155.51, maxLongitude: 166.98),
        "SC": .init(minLatitude: -10.23, maxLatitude: -3.72, minLongitude: 46.20, maxLongitude: 56.28),
        "SE": .init(minLatitude: 55.34, maxLatitude: 69.06, minLongitude: 11.03, maxLongitude: 24.16),
        "SG": .init(minLatitude: 1.16, maxLatitude: 1.47, minLongitude: 103.60, maxLongitude: 104.08),
        "TH": .init(minLatitude: 5.61, maxLatitude: 20.46, minLongitude: 97.34, maxLongitude: 105.64),
        "TO": .init(minLatitude: -21.46, maxLatitude: -15.56, minLongitude: -175.68, maxLongitude: -173.70),
        "TR": .init(minLatitude: 35.82, maxLatitude: 42.11, minLongitude: 25.67, maxLongitude: 44.83),
        "TT": .init(minLatitude: 10.04, maxLatitude: 11.36, minLongitude: -61.93, maxLongitude: -60.52),
        "TW": .init(minLatitude: 21.90, maxLatitude: 25.30, minLongitude: 120.04, maxLongitude: 122.00),
        "TZ": .init(minLatitude: -11.76, maxLatitude: -0.99, minLongitude: 29.34, maxLongitude: 40.45),
        "US": .init(minLatitude: 24.40, maxLatitude: 49.38, minLongitude: -124.85, maxLongitude: -66.89),
        "UY": .init(minLatitude: -34.97, maxLatitude: -30.09, minLongitude: -58.44, maxLongitude: -53.10),
        "VC": .init(minLatitude: 12.58, maxLatitude: 13.38, minLongitude: -61.46, maxLongitude: -61.11),
        "VE": .init(minLatitude: 0.65, maxLatitude: 12.20, minLongitude: -73.37, maxLongitude: -59.80),
        "VG": .init(minLatitude: 18.31, maxLatitude: 18.75, minLongitude: -64.88, maxLongitude: -64.27),
        "VI": .init(minLatitude: 17.67, maxLatitude: 18.41, minLongitude: -65.09, maxLongitude: -64.56),
        "VN": .init(minLatitude: 8.41, maxLatitude: 23.39, minLongitude: 102.14, maxLongitude: 109.46),
        "VU": .init(minLatitude: -20.25, maxLatitude: -13.07, minLongitude: 166.52, maxLongitude: 170.24),
        "WS": .init(minLatitude: -14.05, maxLatitude: -13.43, minLongitude: -172.80, maxLongitude: -171.40),
        "ZA": .init(minLatitude: -34.84, maxLatitude: -22.13, minLongitude: 16.45, maxLongitude: 32.89),
    ]
}
