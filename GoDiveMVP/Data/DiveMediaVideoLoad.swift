import Foundation

/// How a referenced video finished (or failed) loading for playback.
///
/// Explicit **nonisolated** **`Equatable`** keeps Swift Testing **`#expect`** usable in Swift 6 (same pattern as
/// **`UddfMacDiveWatchDatetimeSemantics`**).
enum DiveMediaVideoLoadOutcome: Sendable {
    /// An **`AVPlayerItem`** was produced.
    case loaded
    /// The referenced Photos asset no longer exists — prune the row instead of offering retry.
    case assetMissing
    /// A transient failure / timeout (asset still present, or a local file) — show an error with a retry option.
    case retryable
    /// No network and no local preview/stream — show offline icon only (no retry sheet).
    case offlineUnavailable
}

extension DiveMediaVideoLoadOutcome: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.loaded, .loaded),
             (.assetMissing, .assetMissing),
             (.retryable, .retryable),
             (.offlineUnavailable, .offlineUnavailable):
            return true
        default:
            return false
        }
    }
}

/// Pure rules for the dive video player's load + timeout behavior (testable without AVFoundation / PhotoKit).
enum DiveMediaVideoLoad {
    /// Seconds to wait for a Photos player item before treating playback load as failed. PhotoKit can stall for a
    /// long time (or never call back) while downloading an iCloud original, so we bound the wait and surface retry.
    nonisolated static let timeoutSeconds: Double = 15

    /// Classifies a finished load attempt:
    /// - **`itemResolved`** — a player item was produced before the timeout.
    /// - **`isLibraryAsset`** — the source is a Photos pointer (vs. a local file).
    /// - **`assetStillExists`** — the Photos asset is still reachable (only meaningful for library assets).
    nonisolated static func classify(
        itemResolved: Bool,
        isLibraryAsset: Bool,
        assetStillExists: Bool,
        isNetworkAvailable: Bool = true
    ) -> DiveMediaVideoLoadOutcome {
        if itemResolved { return .loaded }
        if isLibraryAsset, !assetStillExists { return .assetMissing }
        if !isNetworkAvailable { return .offlineUnavailable }
        return .retryable
    }
}
