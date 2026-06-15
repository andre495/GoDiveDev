import Foundation

/// Bright accent colors for logbook trip groups — cycled so neighboring groups differ.
enum LogbookTripGroupAccentPalette: Sendable {

    struct RGB: Sendable, Equatable {
        let red: Double
        let green: Double
        let blue: Double
    }

    /// Distinct, high-chroma options readable on the logbook gradient.
    nonisolated static let palette: [RGB] = [
        RGB(red: 0.10, green: 0.82, blue: 1.00),   // cyan
        RGB(red: 1.00, green: 0.52, blue: 0.12),   // orange
        RGB(red: 0.78, green: 0.38, blue: 1.00),   // purple
        RGB(red: 0.22, green: 0.88, blue: 0.48),   // green
        RGB(red: 1.00, green: 0.36, blue: 0.62),   // pink
        RGB(red: 1.00, green: 0.84, blue: 0.18),   // yellow
        RGB(red: 1.00, green: 0.42, blue: 0.38),   // coral
        RGB(red: 0.38, green: 0.66, blue: 1.00),   // sky blue
    ]

    nonisolated static func rgb(at index: Int) -> RGB {
        guard !palette.isEmpty else { return RGB(red: 1, green: 1, blue: 1) }
        let normalized = ((index % palette.count) + palette.count) % palette.count
        return palette[normalized]
    }

    /// Picks the next palette slot — always differs from **`previousIndex`** when the palette has 2+ colors.
    nonisolated static func nextIndex(after previousIndex: Int?) -> Int {
        guard let previousIndex, palette.count > 1 else { return 0 }
        return (previousIndex + 1) % palette.count
    }
}
