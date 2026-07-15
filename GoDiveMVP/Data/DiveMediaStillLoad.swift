import Foundation

/// Pure rules for PhotoKit still-image loads (testable without PhotoKit).
///
/// Opportunistic requests deliver a local **degraded** thumbnail first, then a **final** frame that may
/// require an iCloud original download. When that download stalls, the request must not hang forever:
/// after **`requestTimeoutSeconds`** the caller resolves with the best degraded frame (displayed, never cached).
enum DiveMediaStillLoad {

    /// Bound wait for a final (non-degraded) PhotoKit frame before falling back to the degraded thumbnail.
    nonisolated static let requestTimeoutSeconds: Double = 20

    /// Only final frames enter session / reference caches — a degraded fallback under a hero-size key
    /// would short-circuit future upgrade lookups.
    nonisolated static func shouldCacheFetchedImage(isFinal: Bool) -> Bool {
        isFinal
    }

    /// On timeout, surface the degraded thumbnail (sharper than the 256 px stored JPEG) instead of nothing.
    nonisolated static func timeoutFallbackImage<Image>(latestDegraded: Image?) -> Image? {
        latestDegraded
    }
}
