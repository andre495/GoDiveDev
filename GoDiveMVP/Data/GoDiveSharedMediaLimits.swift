import Foundation

/// Caps and export targets for friend-visible shared activity media (dives + snorkels).
enum GoDiveSharedMediaLimits: Sendable {
    nonisolated static let maxPhotosPerActivity = 20
    nonisolated static let maxVideosPerActivity = 10
    nonisolated static let maxSharedVideoDurationSeconds: Double = 30

    nonisolated static let photoContentMaxPixelEdge: Int = 4096
    nonisolated static let photoContentMaxBytes = 6_000_000

    nonisolated static let thumbMaxBytes = 1_000_000
    nonisolated static let photoStorageMaxBytes = 8_000_000
    nonisolated static let videoStorageMaxBytes = 50_000_000
}
