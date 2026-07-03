import CoreGraphics
import Foundation

/// PhotoKit delivery tiers for the Fishial still-selection flow.
enum FishialMediaSelectionPresentation: Sendable {
    /// Fast local/degraded still for immediate crop UI (no full iCloud original).
    nonisolated static let photoPreviewMaxEdge: CGFloat = 1_024
    /// Scrub preview frame extraction cap (lighter than Fishial export).
    nonisolated static let videoScrubPreviewMaxEdge: CGFloat = 1_024
    /// Full-quality export cap sent to Fishial after the user crops.
    nonisolated static let photoExportMaxEdge: CGFloat = DiveMediaFishialFrameExport.maxJPEGEdge
    /// Video scrub player uses the same lighter stream as dive overview heroes.
    nonisolated static let videoScrubRequestQuality: DiveMediaVideoRequestQuality = .homeCarousel
    /// Scrubbed still export for crop + Fishial uses full quality.
    nonisolated static let videoExportRequestQuality: DiveMediaVideoRequestQuality = .fullQuality
}
