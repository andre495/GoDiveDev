import Foundation

/// PhotoKit video delivery tier — Home carousel uses a lighter stream; dive detail keeps full quality.
enum DiveMediaVideoRequestQuality: Sendable, Equatable {
    case fullQuality
    case homeCarousel

    nonisolated var cachesInSession: Bool {
        switch self {
        case .fullQuality:
            return true
        case .homeCarousel:
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
