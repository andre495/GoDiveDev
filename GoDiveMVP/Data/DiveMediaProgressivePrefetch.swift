import Foundation
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Background poster + preview warm for adjacent dive media pager items.
@MainActor
enum DiveMediaProgressivePrefetch {

    private static var inflightKeys: Set<String> = []

    static func warmNeighbors(
        mediaItems: [DiveMediaPhoto],
        selectedMediaID: UUID?,
        screenPixelWidth: CGFloat,
        isMediaTabSelected: Bool
    ) {
        guard DiveMediaProgressivePresentation.shouldPrefetchAdjacentMedia(isMediaTabSelected: isMediaTabSelected),
              screenPixelWidth > 0,
              !mediaItems.isEmpty,
              let selectedMediaID,
              let selectedIndex = mediaItems.firstIndex(where: { $0.id == selectedMediaID }) else {
            return
        }

        let indices = DiveMediaProgressivePresentation.prefetchNeighborIndices(
            selectedIndex: selectedIndex,
            itemCount: mediaItems.count
        )
        let posterSize = DiveMediaProgressivePresentation.posterTargetSize(screenPixelWidth: screenPixelWidth)

        for index in indices {
            let media = mediaItems[index]
            guard let identifier = media.libraryAssetLocalIdentifier else { continue }
            let key = "\(identifier)|\(Int(posterSize.width))"
            guard !inflightKeys.contains(key) else { continue }
            inflightKeys.insert(key)

            Task {
                defer { inflightKeys.remove(key) }
                #if canImport(UIKit) && canImport(Photos)
                _ = await DiveMediaReferenceLoader.image(
                    localIdentifier: identifier,
                    targetSize: posterSize,
                    deliveryMode: .opportunistic
                )
                if media.resolvedMediaKind == .video {
                    _ = await DiveMediaReferenceLoader.playerItem(
                        localIdentifier: identifier,
                        quality: DiveActivityMediaPresentation.overviewLibraryVideoQuality
                    )
                }
                #endif
            }
        }
    }
}
