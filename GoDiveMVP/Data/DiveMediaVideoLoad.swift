import Foundation

/// How a referenced video finished (or failed) loading for playback.
enum DiveMediaVideoLoadOutcome: Equatable, Sendable {
    /// An **`AVPlayerItem`** was produced.
    case loaded
    /// The referenced Photos asset no longer exists — prune the row instead of offering retry.
    case assetMissing
    /// A transient failure / timeout (asset still present, or a local file) — show an error with a retry option.
    case retryable
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
        assetStillExists: Bool
    ) -> DiveMediaVideoLoadOutcome {
        if itemResolved { return .loaded }
        if isLibraryAsset, !assetStillExists { return .assetMissing }
        return .retryable
    }
}
