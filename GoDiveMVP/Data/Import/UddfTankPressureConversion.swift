import Foundation

/// MacDive **UDDF** exports tank pressures as **SI Pascal** (values ~2×10⁷ ≈ **3 000 psi**).
enum UddfTankPressureConversion {

    private static let pascalsPerPSI = 6894.757293168361

    /// Converts absolute tank pressure from **Pa** to **psi** for storage on **`DiveActivity`** / **`DiveProfilePoint`**.
    static func psi(fromPascals value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value / pascalsPerPSI
    }
}

/// UDDF **`tankvolume`** is **cubic metres** (MacDive sample **0.080** → **80 L**).
enum UddfTankVolumeFormatting {

    static func volumeDescription(fromCubicMeters cubicMeters: Double?) -> String? {
        guard let v = cubicMeters, v > 0 else { return nil }
        let liters = v * 1000
        return String(format: "%.0f L (%.3f m³)", liters, v)
    }
}
