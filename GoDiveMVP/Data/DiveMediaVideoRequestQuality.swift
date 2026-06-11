import Foundation

/// PhotoKit video delivery tier — preview playback uses a lighter stream; Fishial / export keep full quality.
enum DiveMediaVideoRequestQuality: Sendable, Equatable {
    case fullQuality
    /// Lighter **`.automatic`** stream for Home carousel and dive overview heroes (no session **`AVAsset`** cache).
    case homeCarousel

    nonisolated var cachesInSession: Bool {
        switch self {
        case .fullQuality:
            return true
        case .homeCarousel:
            return false
        }
    }

    nonisolated var sessionCacheKeySuffix: String {
        switch self {
        case .fullQuality:
            return "full"
        case .homeCarousel:
            return "preview"
        }
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
    nonisolated var photoKitDeliveryMode: PHVideoRequestOptionsDeliveryMode {
        switch self {
        case .fullQuality:
            return .highQualityFormat
        case .homeCarousel:
            return .automatic
        }
    }
}
#endif
