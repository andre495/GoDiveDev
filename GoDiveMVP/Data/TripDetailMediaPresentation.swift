import Foundation
import CoreGraphics

/// One dive-media tile on **`TripDetailView`** (parent dive + gallery row).
struct TripDetailLinkedMediaItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let diveActivityID: UUID
    let capturedAt: Date?
    let sortOrder: Int
}

enum TripDetailMediaPresentation: Sendable {

    /// All media from linked dives — newest dive first, gallery order within each dive.
    @MainActor
    static func linkedMediaItems(from activities: [DiveActivity]) -> [TripDetailLinkedMediaItem] {
        let sortedDives = activities.sorted { lhs, rhs in
            if lhs.startTime != rhs.startTime { return lhs.startTime > rhs.startTime }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        var items: [TripDetailLinkedMediaItem] = []
        for dive in sortedDives {
            for photo in DiveActivityMediaPresentation.sortedPhotos(on: dive) {
                items.append(
                    TripDetailLinkedMediaItem(
                        id: photo.id,
                        diveActivityID: dive.id,
                        capturedAt: photo.capturedAt,
                        sortOrder: photo.sortOrder
                    )
                )
            }
        }
        return items
    }

    @MainActor
    static func mediaPhotos(
        from activities: [DiveActivity],
        itemIDs: [TripDetailLinkedMediaItem]
    ) -> [DiveMediaPhoto] {
        let photoByID = Dictionary(
            uniqueKeysWithValues: activities.flatMap(\.mediaPhotos).map { ($0.id, $0) }
        )
        return itemIDs.compactMap { photoByID[$0.id] }
    }

    @MainActor
    static func timeZoneOffsetByMediaID(
        from activities: [DiveActivity],
        itemIDs: [TripDetailLinkedMediaItem]
    ) -> [UUID: Int?] {
        let diveByID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
        var offsets: [UUID: Int?] = [:]
        for item in itemIDs {
            offsets[item.id] = diveByID[item.diveActivityID]?.timeZoneOffsetSeconds
        }
        return offsets
    }

    @MainActor
    static func diveActivityID(
        for mediaID: UUID,
        in items: [TripDetailLinkedMediaItem]
    ) -> UUID? {
        items.first(where: { $0.id == mediaID })?.diveActivityID
    }

    nonisolated static func resolvedHeroMediaPhotoID(
        in photos: [DiveMediaPhoto],
        explicitFeaturedID: UUID?,
        sessionRandomID: UUID?
    ) -> UUID? {
        DetailHeroMediaPresentation.resolvedHeroMediaPhotoID(
            in: photos,
            explicitFeaturedID: explicitFeaturedID,
            sessionRandomID: sessionRandomID
        )
    }

    nonisolated static func toggledFeaturedMediaPhotoID(
        mediaID: UUID,
        explicitFeaturedID: UUID?
    ) -> UUID? {
        DetailHeroMediaPresentation.toggledFeaturedMediaPhotoID(
            mediaID: mediaID,
            explicitFeaturedID: explicitFeaturedID
        )
    }
}

/// Where the featured-media star sits in **`TripDetailMediaGalleryOverlayControls`**.
enum TripDetailMediaGalleryFeaturedStarPlacement: Sendable {
    /// Bottom row beside buddy / fish tag controls (fullscreen grid default).
    case bottomTrailing
    /// Upper trailing corner (dive **Media** tab landscape).
    case topTrailing
}

/// Trip media gallery chrome on **`TripDetailView`**.
enum TripDetailMediaGalleryPresentation: Sendable {
    nonisolated static let previewCornerRadius: CGFloat = 16
    nonisolated static let previewHorizontalInset: CGFloat = 16
    nonisolated static let swipeMinimumDistance: CGFloat = 12
    nonisolated static let swipeAdvanceThreshold: CGFloat = 36
    nonisolated static let browseAnimationDuration: TimeInterval = 0.32
    nonisolated static let browseAnimationDamping: CGFloat = 0.84
    nonisolated static let browseTransitionOffset: CGFloat = 88
    nonisolated static let browseTransitionMinScale: CGFloat = 0.86
    nonisolated static let browseTransitionInsertedOpacity: Double = 0.2
    nonisolated static let browseEdgeResistance: CGFloat = 0.28
    nonisolated static let marineLifeOverlayFeatureImageHeight: CGFloat = 148
    nonisolated static let marineLifeOverlayFeatureImageMaxWidth: CGFloat = 220
    /// Dimming scrim when the overlay sits on top of playing media (Home carousel / full-bleed heroes).
    nonisolated static let marineLifeOverlayMediaScrimOpacity: Double =
        DiveActivityMediaFrostedOverlayPresentation.mediaScrimOpacity
    nonisolated static let marineLifeOverlayTranslucentPanelOpacity: Double = 0.9
    /// Matches dive-media capture timestamp capsule (**`DiveActivityMediaItemView`**).
    nonisolated static let overlayChipHorizontalPadding: CGFloat = 10
    nonisolated static let overlayChipVerticalPadding: CGFloat = 6
    nonisolated static let overlayChipBackgroundOpacity: Double = 0.55

    nonisolated static func previewSize(in container: CGSize) -> CGSize {
        let width = max(container.width - previewHorizontalInset * 2, 1)
        return CGSize(width: width, height: container.height)
    }

    nonisolated static func taggedSpecies(
        mediaID: UUID?,
        sightings: [SightingInstance],
        catalog: [MarineLife]
    ) -> [MarineLife] {
        guard let mediaID else { return [] }
        return MarineLifeMediaTagPresentation.resolvedTaggedSpecies(
            mediaPhotoID: mediaID,
            sightings: sightings,
            catalog: catalog
        )
    }

    /// **`+1`** = next item (swipe up), **`-1`** = previous (swipe down).
    nonisolated static func browseOffset(forVerticalTranslation translation: CGFloat) -> Int? {
        guard abs(translation) >= swipeAdvanceThreshold else { return nil }
        if translation < 0 { return 1 }
        if translation > 0 { return -1 }
        return nil
    }

    /// Normalized drag progress (**`0…1`**) for interactive browse chrome.
    nonisolated static func interactiveBrowseProgress(
        verticalTranslation: CGFloat,
        previewHeight: CGFloat
    ) -> CGFloat {
        guard previewHeight > 0 else { return 0 }
        return min(abs(verticalTranslation) / previewHeight, 1)
    }

    nonisolated static func interactiveCurrentScale(progress: CGFloat) -> CGFloat {
        1 - (1 - browseTransitionMinScale) * progress
    }

    nonisolated static func interactiveAdjacentScale(progress: CGFloat) -> CGFloat {
        browseTransitionMinScale + (1 - browseTransitionMinScale) * progress
    }

    nonisolated static func interactiveCurrentOpacity(progress: CGFloat) -> Double {
        1 - (1 - browseTransitionInsertedOpacity) * Double(progress)
    }

    nonisolated static func interactiveAdjacentOpacity(progress: CGFloat) -> Double {
        browseTransitionInsertedOpacity + (1 - browseTransitionInsertedOpacity) * Double(progress)
    }

    /// Y offset for the incoming item while the current frame follows the finger.
    nonisolated static func adjacentItemOffset(
        verticalTranslation: CGFloat,
        previewHeight: CGFloat
    ) -> CGFloat {
        if verticalTranslation < 0 {
            return previewHeight + verticalTranslation
        }
        if verticalTranslation > 0 {
            return -previewHeight + verticalTranslation
        }
        return 0
    }

    nonisolated static func rubberBandedBrowseTranslation(
        _ translation: CGFloat,
        canBrowseForward: Bool,
        canBrowseBackward: Bool,
        resistance: CGFloat = browseEdgeResistance
    ) -> CGFloat {
        if translation < 0, !canBrowseForward { return translation * resistance }
        if translation > 0, !canBrowseBackward { return translation * resistance }
        return translation
    }

    nonisolated static func interactiveCommitTranslation(step: Int, previewHeight: CGFloat) -> CGFloat {
        step > 0 ? -previewHeight : previewHeight
    }

    nonisolated static func interactiveBrowseStep(forVerticalTranslation translation: CGFloat) -> Int? {
        if translation < 0 { return 1 }
        if translation > 0 { return -1 }
        return nil
    }

    @MainActor
    static func mediaPositionLabel(selectedID: UUID?, in photos: [DiveMediaPhoto]) -> String? {
        guard let resolvedID = DiveActivityMediaPresentation.resolvedSelectedPhotoID(
            selectedID: selectedID,
            in: photos
        ),
        let index = photos.firstIndex(where: { $0.id == resolvedID })
        else { return nil }

        return "\(index + 1) of \(photos.count)"
    }

    nonisolated static func showsMarineLifeTagIndicator(
        mediaID: UUID?,
        sightings: [SightingInstance]
    ) -> Bool {
        guard let mediaID else { return false }
        return MarineLifeMediaTagPresentation.hasTaggedSpeciesOnMedia(
            mediaPhotoID: mediaID,
            sightings: sightings
        )
    }

    nonisolated static func browseAccessibilityLabel(
        itemCount: Int,
        positionLabel: String?,
        hasTaggedMarineLife: Bool = false
    ) -> String {
        guard itemCount > 0 else { return DiveTripPresentation.tripMediaEmptyMessage }
        let countPhrase = itemCount == 1 ? "1 item" : "\(itemCount) items"
        guard let positionLabel else { return "Trip media, \(countPhrase)" }
        var label = "Trip media, \(positionLabel)"
        if hasTaggedMarineLife {
            label += ", marine life tagged"
        }
        if itemCount > 1 {
            label += ", swipe up for next, swipe down for previous"
        }
        if hasTaggedMarineLife {
            label += ", tap fish icon for marine life overview"
        }
        label += ", \(DiveTripPresentation.tripMediaOpenOnDiveButtonTitle) opens the linked dive"
        return label
    }
}

enum TripDetailMediaBrowseDirection: Sendable {
    case forward
    case backward
}
