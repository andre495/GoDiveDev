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
    /// Soft timeout when PhotoKit never reports iCloud progress; hard cap when a download is crawling.
    /// Streaming **`requestPlayerItem`** should return well under this when we do not touch **`.asset`**.
    nonisolated static let softTimeoutSeconds: Double = 15
    nonisolated static let hardTimeoutSeconds: Double = 90

    /// Reading **`AVPlayerItem.asset`** inside PhotoKit’s player-item callback can block on a full iCloud
    /// download — Home playback must keep the streaming item and never extract **`.asset`** there.
    nonisolated static func shouldExtractAssetInPlayerItemCallback() -> Bool {
        false
    }

    /// Default seconds when a caller does not pass a quality-specific timeout.
    nonisolated static let timeoutSeconds: Double = softTimeoutSeconds

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

    /// After a timed-out or failed PhotoKit request, prefer a sibling warm that filled the session cache.
    nonisolated static func preferredAssetAfterRequest(
        requestedAssetResolved: Bool,
        sessionCachedAvailable: Bool
    ) -> Bool {
        requestedAssetResolved || sessionCachedAvailable
    }

    /// Fail at soft timeout only with no iCloud progress; always fail at the hard cap.
    nonisolated static func shouldFailVideoRequest(
        elapsedSeconds: Double,
        hasSeenProgress: Bool,
        softTimeoutSeconds: Double = softTimeoutSeconds,
        hardTimeoutSeconds: Double = hardTimeoutSeconds
    ) -> Bool {
        if elapsedSeconds >= hardTimeoutSeconds { return true }
        if elapsedSeconds >= softTimeoutSeconds, !hasSeenProgress { return true }
        return false
    }

    /// Compact Console detail for a failed / timed-out library video request.
    nonisolated static func requestFailureDetail(
        timedOut: Bool,
        networkAllowed: Bool,
        elapsedSeconds: Double,
        isInCloud: Bool?,
        errorDescription: String?,
        hasSeenProgress: Bool = false
    ) -> String {
        var parts: [String] = [
            timedOut ? "timedOut" : "photoKitNil",
            "net=\(networkAllowed ? "1" : "0")",
            String(format: "%.1fs", elapsedSeconds),
        ]
        if hasSeenProgress {
            parts.append("progress=1")
        }
        if let isInCloud {
            parts.append("iCloud=\(isInCloud ? "1" : "0")")
        }
        if let errorDescription, !errorDescription.isEmpty {
            parts.append(errorDescription)
        }
        return parts.joined(separator: " ")
    }
}
