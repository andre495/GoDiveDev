import Foundation

/// Copy and ordering rules for dive **Media** tab items (testable without SwiftUI).
enum DiveActivityMediaPresentation: Sendable {

    nonisolated static let emptyStateMessage = "No media added"

    /// Background gallery is hidden when the overview sheet is **large** (sheet-only chrome).
    nonisolated static func showsBackgroundPhotos(for detent: DiveActivityOverviewDetent) -> Bool {
        detent != .large
    }

    /// Muted, looping background video plays on the **Media** tab at **minimized** or **medium** detent.
    nonisolated static func shouldPlayBackgroundVideo(
        isMediaTabSelected: Bool,
        detent: DiveActivityOverviewDetent
    ) -> Bool {
        isMediaTabSelected && showsBackgroundPhotos(for: detent)
    }

    nonisolated static func sortedMedia(on activity: DiveActivity) -> [DiveMediaPhoto] {
        sortedPhotos(on: activity)
    }

    nonisolated static func sortedPhotos(on activity: DiveActivity) -> [DiveMediaPhoto] {
        sortedPhotos(activity.mediaPhotos)
    }

    nonisolated static func sortedPhotos(_ photos: [DiveMediaPhoto]) -> [DiveMediaPhoto] {
        photos.sorted(by: isOrderedBeforeInGallery)
    }

    /// First item in gallery order (oldest **`capturedAt`** when set).
    nonisolated static func oldestGalleryPhotoID(in photos: [DiveMediaPhoto]) -> UUID? {
        sortedPhotos(photos).first?.id
    }

    nonisolated static func oldestGalleryPhotoID(on activity: DiveActivity) -> UUID? {
        oldestGalleryPhotoID(in: activity.mediaPhotos)
    }

    /// Resolved **featured** media: the user-chosen **`explicitFeaturedID`** when it still exists in **`photos`**,
    /// otherwise the default (oldest gallery item). Falls back gracefully if the featured asset was removed / pruned.
    nonisolated static func featuredPhotoID(in photos: [DiveMediaPhoto], explicitFeaturedID: UUID?) -> UUID? {
        if let explicitFeaturedID, photos.contains(where: { $0.id == explicitFeaturedID }) {
            return explicitFeaturedID
        }
        return oldestGalleryPhotoID(in: photos)
    }

    nonisolated static func featuredPhotoID(on activity: DiveActivity) -> UUID? {
        featuredPhotoID(in: activity.mediaPhotos, explicitFeaturedID: activity.featuredMediaPhotoID)
    }

    /// **`true`** when **`mediaID`** is the resolved featured item for **`photos`**.
    nonisolated static func isFeatured(
        mediaID: UUID,
        in photos: [DiveMediaPhoto],
        explicitFeaturedID: UUID?
    ) -> Bool {
        featuredPhotoID(in: photos, explicitFeaturedID: explicitFeaturedID) == mediaID
    }

    /// Gallery / carousel order: oldest **`capturedAt`** first (left); undated items last, then **`sortOrder`**, then **`id`**.
    nonisolated static func isOrderedBeforeInGallery(_ lhs: DiveMediaPhoto, _ rhs: DiveMediaPhoto) -> Bool {
        switch (lhs.capturedAt, rhs.capturedAt) {
        case let (left?, right?):
            if left != right { return left < right }
        case (nil, .some):
            return false
        case (.some, nil):
            return true
        case (nil, nil):
            break
        }
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    nonisolated static func hasDisplayableMedia(on activity: DiveActivity) -> Bool {
        !sortedPhotos(on: activity).isEmpty
    }

    /// Date/time + dive-position subtitle on the **Media** hero at **minimized** only (details row at **medium**).
    nonisolated static func showsCaptureDateOnHero(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .minimized
    }

    /// **Tag marine life** control on the visible hero item at **minimized** only (**medium** uses the sheet).
    nonisolated static func showsMarineLifeTagOnHero(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .minimized
    }

    /// **Tag marine life** control in the **Media** sheet chrome at **medium** (top leading).
    nonisolated static func showsMarineLifeTagInSheet(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .medium
    }

    /// Thumbnail strip in the **Media** sheet at **minimized** and **medium** detents.
    nonisolated static func showsMediaCarouselInSheet(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .minimized || detent == .medium
    }

    /// Capture date block and header **+** at **medium** only (no title / position row).
    nonisolated static func showsMediaSheetDetails(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .medium
    }

    nonisolated static let carouselThumbnailSize: CGFloat = 72
    /// Square preview on logbook activity rows (trailing).
    /// Fallback square extent before the logbook row measures its text column.
    nonisolated static let logbookRowMediaPreviewMinExtent: CGFloat = 48
    nonisolated static let logbookRowMediaPreviewCornerRadius: CGFloat = 6
    nonisolated static let carouselThumbnailSpacing: CGFloat = 10
    nonisolated static let carouselThumbnailCornerRadius: CGFloat = 10
    /// Fixed row height so the carousel lays out inside the overview panel's vertical **`ScrollView`**.
    nonisolated static var carouselRowHeight: CGFloat { carouselThumbnailSize + 4 }

    nonisolated static let captureDateUnknownMessage = "Capture date unavailable"

    nonisolated static func selectedMedia(
        selectedID: UUID?,
        in photos: [DiveMediaPhoto]
    ) -> DiveMediaPhoto? {
        guard let resolvedID = resolvedSelectedPhotoID(selectedID: selectedID, in: photos) else { return nil }
        return photos.first { $0.id == resolvedID }
    }

    nonisolated static func mediaPositionLabel(selectedID: UUID?, in photos: [DiveMediaPhoto]) -> String? {
        guard let resolvedID = resolvedSelectedPhotoID(selectedID: selectedID, in: photos),
              let index = photos.firstIndex(where: { $0.id == resolvedID })
        else { return nil }

        let kindLabel = photos[index].resolvedMediaKind == .video ? "Video" : "Photo"
        return "\(kindLabel) \(index + 1) of \(photos.count)"
    }

    static func captureDatePanelText(for media: DiveMediaPhoto, timeZoneOffsetSeconds: Int?) -> String {
        formattedCapturedAt(media, timeZoneOffsetSeconds: timeZoneOffsetSeconds) ?? captureDateUnknownMessage
    }

    static func formattedCapturedAt(_ media: DiveMediaPhoto, timeZoneOffsetSeconds: Int?) -> String? {
        guard let capturedAt = media.capturedAt else { return nil }
        return DiveActivityTimePresentation.formatDateTime(capturedAt, timeZoneOffsetSeconds: timeZoneOffsetSeconds)
    }

    /// **Captured at 45.0 ft, 12 minutes into the dive.** (unit-aware depth).
    nonisolated static func formattedCaptureAtDivePosition(
        context: DiveMediaCaptureContext,
        displayUnits: DiveDisplayUnitSystem
    ) -> String {
        let depth = DiveQuantityFormatting.depth(meters: context.depthMeters, system: displayUnits)
        let elapsed = formattedMinutesIntoDive(elapsedSeconds: context.elapsedSeconds)
        return "Captured at \(depth), \(elapsed)"
    }

    nonisolated static func formattedMinutesIntoDive(elapsedSeconds: Double) -> String {
        let minutes = elapsedSeconds / 60.0
        let roundedToTenth = (minutes * 10).rounded() / 10
        if abs(roundedToTenth - roundedToTenth.rounded()) < 0.001 {
            let whole = Int(roundedToTenth.rounded())
            return whole == 1 ? "1 minute into the dive" : "\(whole) minutes into the dive"
        }
        return String(format: "%.1f minutes into the dive", roundedToTenth)
    }

    /// Bottom overlay on full-screen media preview (date/time + optional profile position).
    static func mediaPreviewCaptureOverlayLines(
        media: DiveMediaPhoto,
        captureContext: DiveMediaCaptureContext?,
        timeZoneOffsetSeconds: Int?,
        displayUnits: DiveDisplayUnitSystem
    ) -> (dateTimeLine: String, divePositionLine: String?)? {
        guard let dateTimeLine = formattedCapturedAt(media, timeZoneOffsetSeconds: timeZoneOffsetSeconds) else {
            return nil
        }
        let divePositionLine = captureContext.map {
            formattedCaptureAtDivePosition(context: $0, displayUnits: displayUnits)
        }
        return (dateTimeLine, divePositionLine)
    }

    static func mediaPreviewCaptureAccessibilityLabel(
        media: DiveMediaPhoto,
        captureContext: DiveMediaCaptureContext?,
        timeZoneOffsetSeconds: Int?,
        displayUnits: DiveDisplayUnitSystem
    ) -> String? {
        guard let overlay = mediaPreviewCaptureOverlayLines(
            media: media,
            captureContext: captureContext,
            timeZoneOffsetSeconds: timeZoneOffsetSeconds,
            displayUnits: displayUnits
        ) else { return nil }
        if let divePositionLine = overlay.divePositionLine {
            return "Captured \(overlay.dateTimeLine). \(divePositionLine)"
        }
        return "Captured \(overlay.dateTimeLine)"
    }

    nonisolated static func mediaCountLabel(photoCount: Int) -> String {
        switch photoCount {
        case 0:
            return emptyStateMessage
        case 1:
            return "1 item"
        default:
            return "\(photoCount) items"
        }
    }

    nonisolated static func nextSortOrder(on activity: DiveActivity) -> Int {
        let orders = activity.mediaPhotos.map(\.sortOrder)
        return (orders.max() ?? -1) + 1
    }

    /// Keeps pager selection valid when the photo list changes.
    nonisolated static func resolvedSelectedPhotoID(
        selectedID: UUID?,
        in photos: [DiveMediaPhoto]
    ) -> UUID? {
        guard !photos.isEmpty else { return nil }
        if let selectedID, photos.contains(where: { $0.id == selectedID }) {
            return selectedID
        }
        return photos.first?.id
    }

    /// PhotoKit request edge for full-bleed pager photos — screen pixel width, clamped for memory.
    nonisolated static func fullScreenImageTargetEdge(screenPixelWidth: CGFloat) -> CGFloat {
        min(max(max(screenPixelWidth, 1), 800), 2_048)
    }
}
