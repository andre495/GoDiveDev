import Foundation

/// PhotoKit video delivery tier — preview playback uses a lighter stream; Fishial / export keep full quality.
enum DiveMediaVideoRequestQuality: Sendable, Equatable {
    case fullQuality
    /// Lighter **`.automatic`** stream for Home carousel and dive overview heroes.
    case homeCarousel

    nonisolated var cachesInSession: Bool {
        true
    }

    nonisolated var sessionCacheKeySuffix: String {
        switch self {
        case .fullQuality:
            return "full"
        case .homeCarousel:
            return "preview"
        }
    }

    /// Home / overview playback uses **`requestPlayerItem`** so iCloud can stream; export / Fishial keep **`requestAVAsset`**.
    nonisolated var usesPlayerItemRequest: Bool {
        switch self {
        case .homeCarousel:
            return true
        case .fullQuality:
            return false
        }
    }

    /// Bound wait for PhotoKit video callbacks. Soft fail without iCloud progress; hard cap is higher.
    nonisolated var requestTimeoutSeconds: Double {
        DiveMediaVideoLoad.softTimeoutSeconds
    }

    /// Absolute maximum wait while iCloud progress is still advancing.
    nonisolated var requestHardTimeoutSeconds: Double {
        DiveMediaVideoLoad.hardTimeoutSeconds
    }
}

extension DiveMediaVideoRequestQuality {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.fullQuality, .fullQuality), (.homeCarousel, .homeCarousel):
            return true
        default:
            return false
        }
    }
}

#if canImport(Photos)
import Photos

extension DiveMediaVideoRequestQuality {
    /// **`.mediumQualityFormat`** streams a medium rendition for iCloud-remote originals.
    /// **`.automatic`** resolved to the full-quality asset on optimized-storage libraries, forcing a large
    /// download that consistently blew the request timeout (observed on device: no callback in 20–30 s).
    nonisolated var photoKitDeliveryMode: PHVideoRequestOptionsDeliveryMode {
        switch self {
        case .fullQuality:
            return .highQualityFormat
        case .homeCarousel:
            return .mediumQualityFormat
        }
    }
}
#endif
