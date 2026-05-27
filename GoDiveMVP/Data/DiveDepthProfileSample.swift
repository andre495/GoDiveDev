import Foundation

/// Kept **outside** SwiftData-touching files so profile value types are not Swift-6–inferred as **Main actor**
/// along with **`@Model`** (fixes **`Equatable`** in **`#expect`** and off-main derived-data builders).

/// One point in a depth-vs-time profile (time from first sample).
struct DiveDepthProfileSample: Equatable, Sendable {
    var elapsedSeconds: Double
    var depthMeters: Double

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.elapsedSeconds == rhs.elapsedSeconds && lhs.depthMeters == rhs.depthMeters
    }
}

/// Remaining cylinder pressure at elapsed time (subset of profile samples with **`tankPressurePSI`**).
struct DiveDepthProfilePressureSample: Equatable, Sendable {
    var elapsedSeconds: Double
    var pressurePSI: Double

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.elapsedSeconds == rhs.elapsedSeconds && lhs.pressurePSI == rhs.pressurePSI
    }
}

/// Depth and elapsed time on the dive profile when media was captured.
struct DiveMediaCaptureContext: Equatable, Sendable {
    var elapsedSeconds: Double
    var depthMeters: Double

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.elapsedSeconds == rhs.elapsedSeconds && lhs.depthMeters == rhs.depthMeters
    }
}
