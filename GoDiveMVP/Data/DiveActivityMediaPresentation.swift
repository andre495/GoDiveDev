import Foundation

/// Copy and ordering rules for dive **Media** tab items (testable without SwiftUI).
enum DiveActivityMediaPresentation: Sendable {

    nonisolated static let emptyStateMessage = "No media added"

    /// PhotoKit tier for dive overview / tagged-media hero video — matches Home carousel preview playback.
    nonisolated static let overviewLibraryVideoQuality: DiveMediaVideoRequestQuality = .homeCarousel

    /// Background gallery stays visible at every detent so dive media remains full-bleed behind the sheet.
    nonisolated static func showsBackgroundPhotos(for detent: DiveActivityOverviewDetent) -> Bool {
        _ = detent
        return true
    }

    /// Muted, looping background video plays on the **Media** tab at **minimized** or **medium** detent.
    nonisolated static func shouldPlayBackgroundVideo(
        isMediaTabSelected: Bool,
        detent: DiveActivityOverviewDetent
    ) -> Bool {
        isMediaTabSelected && showsBackgroundPhotos(for: detent)
    }

    /// Mount an **`AVPlayer`** only for the selected paging page — keeps LazyHStack neighbors on posters
    /// so rapid carousel / swipe between library videos cannot race shared session invalidate + item ownership.
    nonisolated static func mountsVideoPlayerForActivePlayback(_ isVideoPlaybackActive: Bool) -> Bool {
        isVideoPlaybackActive
    }

    @MainActor
    static func sortedMedia(on activity: DiveActivity) -> [DiveMediaPhoto] {
        sortedPhotos(on: activity)
    }

    @MainActor
    static func sortedPhotos(on activity: DiveActivity) -> [DiveMediaPhoto] {
        sortedPhotos(activity.mediaPhotos)
    }

    @MainActor
    static func sortedPhotos(_ photos: [DiveMediaPhoto]) -> [DiveMediaPhoto] {
        photos.sorted { isOrderedBeforeInGallery($0, $1) }
    }

    /// First item in gallery order (oldest **`capturedAt`** when set).
    @MainActor
    static func oldestGalleryPhotoID(in photos: [DiveMediaPhoto]) -> UUID? {
        sortedPhotos(photos).first?.id
    }

    @MainActor
    static func oldestGalleryPhotoID(on activity: DiveActivity) -> UUID? {
        oldestGalleryPhotoID(in: activity.mediaPhotos)
    }

    /// Resolved **featured** media: the user-chosen **`explicitFeaturedID`** when it still exists in **`photos`**,
    /// otherwise the default (oldest gallery item). Falls back gracefully if the featured asset was removed / pruned.
    @MainActor
    static func featuredPhotoID<T: ActivityOverviewGalleryMedia>(
        in photos: [T],
        explicitFeaturedID: UUID?
    ) -> UUID? {
        if let explicitFeaturedID, photos.contains(where: { $0.id == explicitFeaturedID }) {
            return explicitFeaturedID
        }
        return photos.sorted { isOrderedBeforeInGallery($0, $1) }.first?.id
    }

    @MainActor
    static func featuredPhotoID(on activity: DiveActivity) -> UUID? {
        featuredPhotoID(in: activity.mediaPhotos, explicitFeaturedID: activity.featuredMediaPhotoID)
    }

    /// **`true`** when **`mediaID`** is the resolved featured item for **`photos`**.
    @MainActor
    static func isFeatured(
        mediaID: UUID,
        in photos: [DiveMediaPhoto],
        explicitFeaturedID: UUID?
    ) -> Bool {
        featuredPhotoID(in: photos, explicitFeaturedID: explicitFeaturedID) == mediaID
    }

    /// Gallery / carousel order: oldest **`capturedAt`** first (left); undated items last, then **`sortOrder`**, then **`id`**.
    @MainActor
    static func isOrderedBeforeInGallery(_ lhs: DiveMediaPhoto, _ rhs: DiveMediaPhoto) -> Bool {
        GalleryMediaOrdering.isOrderedBefore(orderFields(lhs), orderFields(rhs))
    }

    @MainActor
    static func isOrderedBeforeInGallery<T: ActivityOverviewGalleryMedia>(_ lhs: T, _ rhs: T) -> Bool {
        GalleryMediaOrdering.isOrderedBefore(orderFields(lhs), orderFields(rhs))
    }

    @MainActor
    private static func orderFields<T: ActivityOverviewGalleryMedia>(_ media: T) -> GalleryMediaOrderFields {
        GalleryMediaOrderFields(
            id: media.id,
            capturedAt: media.capturedAt,
            sortOrder: media.sortOrder
        )
    }

    @MainActor
    static func hasDisplayableMedia(on activity: DiveActivity) -> Bool {
        !sortedPhotos(on: activity).isEmpty
    }

    /// Date/time + dive-position subtitle on the **Media** hero at **minimized** only.
    nonisolated static func showsCaptureDateOnHero(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .minimized
    }

    /// Minimized hero capture chip uses the same Liquid Glass capsule as fullscreen / Home dive link chrome.
    nonisolated static func usesLiquidGlassCaptureOverlayOnHero(for detent: DiveActivityOverviewDetent) -> Bool {
        showsCaptureDateOnHero(for: detent)
    }

    /// Landscape **Media** tab — **`LinkedMediaFullscreenView`**-style play/pause + buddy/fish chrome over the pager.
    nonisolated static func showsLandscapeGridStyleMediaChrome(isLandscape: Bool, hasMedia: Bool) -> Bool {
        isLandscape && hasMedia
    }

    /// Breathing room between the capture oval and the top edge of the overview sheet.
    nonisolated static let captureOverlayClearanceAboveSheet: CGFloat = 10

    /// Bottom inset for the capture oval so it sits above the resting overview panel (full-bleed hero).
    nonisolated static func captureOverlayBottomInset(
        layoutHeight: CGFloat,
        detent: DiveActivityOverviewDetent,
        bottomSafeInset: CGFloat
    ) -> CGFloat {
        guard showsCaptureDateOnHero(for: detent), layoutHeight > 0 else { return 0 }
        return DiveActivityOverviewDetent.bottomObstructionHeight(
            layoutHeight: layoutHeight,
            detent: detent,
            bottomSafeInset: bottomSafeInset
        ) + captureOverlayClearanceAboveSheet
    }

    /// Hero overlay fish control — retired; tagging lives in sheet / carousel chrome.
    nonisolated static func showsMarineLifeTagOnHero(for detent: DiveActivityOverviewDetent) -> Bool {
        _ = detent
        return false
    }

    /// Fish tag beside the carousel at **minimized** (leading **+** add media).
    nonisolated static func showsMarineLifeTagInCarousel(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .minimized
    }

    /// Full-bleed hero under translucent **Media** overview panels at every detent.
    nonisolated static func usesFullBleedMediaHero(for detent: DiveActivityOverviewDetent) -> Bool {
        _ = detent
        return true
    }

    /// Opaque embedded panel — same blue gradient as map / tank (**`AppOverviewSheetPanelBackground`**).
    nonisolated static func usesTranslucentOverviewPanel(for detent: DiveActivityOverviewDetent) -> Bool {
        _ = detent
        return false
    }

    /// Tagged-species oval chips at **medium** expand the sheet to **large** species detail.
    nonisolated static func opensMarineLifeDetailOnTaggedChipTap(
        detent: DiveActivityOverviewDetent,
        taggedSpeciesCount: Int
    ) -> Bool {
        detent == .large && taggedSpeciesCount > 0
    }

    /// Sheet chrome **fish** at **medium** expands to **large** (tagging lives on the **large** **+**).
    nonisolated static func opensMarineLifeDetailOnSheetFishTap(
        detent: DiveActivityOverviewDetent
    ) -> Bool {
        detent == .large
    }

    /// Sheet chrome **buddy** at **medium** expands to **large** with the buddy overview selected.
    nonisolated static func opensBuddyOverviewOnSheetBuddyTap(
        detent: DiveActivityOverviewDetent
    ) -> Bool {
        detent == .large
    }

    /// **`DiveOverviewMapTopScrim`** (hero black fade) — map and tank only; **Media** keeps the hero unobscured.
    nonisolated static func showsHeroTopChromeScrim(isMediaTabSelected: Bool) -> Bool {
        !isMediaTabSelected
    }

    /// Outer panel scroll fade — **Media** **large** owns scroll under pinned chrome, so this stays **0**.
    nonisolated static func panelTopScrollFadeHeight(
        detent: DiveActivityOverviewDetent,
        isMediaTabSelected: Bool
    ) -> CGFloat {
        _ = detent
        _ = isMediaTabSelected
        return 0
    }

    /// Soft top feather under the pinned fish/buddy toggle/**+** while body content scrolls.
    nonisolated static var largeDetentPinnedChromeScrollFadeHeight: CGFloat {
        largeDetentTagOverviewChromeHeight
            + DiveActivityOverviewPanelMetrics.mediaLargeDetentPinnedChromeFadeExtra
    }

    /// **`true`** at **large** so scroll feather fades into opaque panel blue, not the hero.
    nonisolated static func panelTopScrollUsesOpaqueFadeBackground(
        detent: DiveActivityOverviewDetent,
        isMediaTabSelected: Bool
    ) -> Bool {
        isMediaTabSelected && detent == .large
    }

    /// **`true`** when the user confirmed this catalog species via Fishial on the media item.
    @MainActor
    static func speciesWasFishialIdentified(
        species: MarineLife,
        on media: DiveMediaPhoto
    ) -> Bool {
        speciesWasFishialIdentified(species: species, confirmedNames: media.resolvedFishialConfirmedSpeciesNames)
    }

    @MainActor
    static func speciesWasFishialIdentified(
        species: MarineLife,
        on media: some ActivityOverviewGalleryMedia
    ) -> Bool {
        speciesWasFishialIdentified(species: species, confirmedNames: media.resolvedFishialConfirmedSpeciesNames)
    }

    private nonisolated static func speciesWasFishialIdentified(
        species: MarineLife,
        confirmedNames: [String]
    ) -> Bool {
        guard !confirmedNames.isEmpty else { return false }
        return confirmedNames.contains {
            species.scientificName.caseInsensitiveCompare($0) == .orderedSame
        }
    }

    /// Selected chip at **medium** should open that species at **large** when still tagged.
    nonisolated static func resolvedTaggedSpeciesUUID(
        selectedUUID: String?,
        taggedSpeciesUUIDs: [String]
    ) -> String? {
        guard !taggedSpeciesUUIDs.isEmpty else { return nil }
        if let selectedUUID, taggedSpeciesUUIDs.contains(selectedUUID) {
            return selectedUUID
        }
        return taggedSpeciesUUIDs.first
    }

    /// Oval-chip marine life summary in the **Media** sheet at **medium** only.
    nonisolated static func showsMarineLifeTagSummaryInSheet(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .large
    }

    /// Buddy avatar strip under marine life on the **Media** sheet at **medium** only.
    nonisolated static func showsBuddyTagSummaryInSheet(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .large
    }

    /// Dive **#** / site / place / date header (same as map medium) on the **Media** sheet at **medium** only.
    nonisolated static func showsDiveIdentityHeaderInSheet(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .large
    }

    /// Species hero + natural-history detail in the **Media** sheet at **large** only.
    nonisolated static func showsMarineLifeDetailInSheet(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .large
    }

    /// **Tag marine life** control in the **Media** sheet chrome at **medium** only.
    nonisolated static func showsMarineLifeTagInSheet(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .large
    }

    /// **Tag buddies** control in the **Media** sheet chrome at **medium** only.
    nonisolated static func showsBuddyTagInSheet(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .large
    }

    /// Marine-life fish control uses accent when at least one species is tagged on the media item.
    nonisolated static func marineLifeTagControlIsActive(taggedSpeciesCount: Int) -> Bool {
        taggedSpeciesCount > 0
    }

    /// Buddy control uses accent when at least one buddy is tagged on the media item.
    nonisolated static func buddyTagControlIsActive(taggedBuddyCount: Int) -> Bool {
        taggedBuddyCount > 0
    }

    /// Fishial sparkles control uses accent after the user confirms and applies a catalog match.
    nonisolated static func fishialIdentifyControlIsActive(confirmedSpeciesName: String?) -> Bool {
        guard let confirmedSpeciesName else { return false }
        return !confirmedSpeciesName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Reserved top chrome clearance — unused; fish / buddy sit on the dive-number row at **medium**.
    nonisolated static func showsMediaSheetChromeActions(for detent: DiveActivityOverviewDetent) -> Bool {
        _ = detent
        return false
    }

    /// Fish / buddy trailing the dive-number / identity header at **medium**.
    nonisolated static func showsMediumDetentTrailingTagChrome(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .large
    }

    /// Carousel star: always on the featured preview; also on the **selected** preview (white when not featured).
    nonisolated static func showsCarouselFeaturedStar(isSelected: Bool, isFeatured: Bool) -> Bool {
        isSelected || isFeatured
    }

    /// Accent (blue) when featured; white when selected but not featured.
    nonisolated static func carouselFeaturedStarUsesAccent(isFeatured: Bool) -> Bool {
        isFeatured
    }

    /// Star glyph size tracks selected / unselected thumbnail extent.
    nonisolated static func carouselFeaturedStarFontSize(isSelected: Bool) -> CGFloat {
        carouselThumbnailExtent(isSelected: isSelected) * 0.22
    }

    /// Trailing **+** on the **large** tagged-species sheet — opens the marine-life tag flow.
    nonisolated static func showsLargeDetentAddMarineLifeControl(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .large
    }

    /// Trailing **+** on the **large** buddy overview — opens the buddy tag flow.
    nonisolated static func showsLargeDetentAddBuddyControl(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .large
    }

    /// Fish / buddy mode toggle + **+** chrome on the **large** Media sheet when media exists.
    nonisolated static func showsLargeDetentTagOverviewChrome(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .large
    }

    /// Reserves space for the fish/buddy toggle row (**segment** + shell padding).
    nonisolated static var largeDetentTagOverviewChromeHeight: CGFloat {
        PushedDetailHeroModeTogglePresentation.segmentSize
            + (PushedDetailHeroModeTogglePresentation.shellPadding * 2)
    }

    /// Hero band height for tagged-species detail at the **large** media detent.
    nonisolated static let largeDetentSpeciesHeroHeight: CGFloat = 220

    /// Species photo hero at **large** Media detent — top fades out like Home fish overlay feature image.
    nonisolated static var largeDetentSpeciesHeroTopFadeOpaqueStop: CGFloat {
        HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageFadeOpaqueStop
    }

    /// Thumbnail strip in the **Media** sheet — **minimized** / **medium** only (not **large** species detail).
    nonisolated static func showsMediaCarouselInSheet(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .minimized
    }

    /// Top chrome action row height at **medium** / **large** — matches **44 pt** action targets.
    nonisolated static let sheetChromeRowHeight: CGFloat = 44

    /// Vertical space reserved above a **legacy** fixed-height carousel stack (tests / empty-state sizing).
    /// Live **medium** Media layout bottom-pins the carousel and gives remaining height to identity + tags.
    nonisolated static func sheetBodyHeightAboveMediaCarousel(
        layoutHeight: CGFloat,
        detent: DiveActivityOverviewDetent
    ) -> CGFloat {
        let inset = DiveActivityOverviewPanelMetrics.mediaCarouselScreenAlignmentTopInset(
            layoutHeight: layoutHeight,
            detent: detent
        )
        let chromeReserve = showsMediaSheetChromeActions(for: detent) ? sheetChromeRowHeight : 0
        return max(0, inset - chromeReserve)
    }

    /// Fixed stack height for the historical minimized-slot alignment math (tests).
    nonisolated static func mediaCarouselPinnedStackHeight(
        layoutHeight: CGFloat,
        detent: DiveActivityOverviewDetent
    ) -> CGFloat {
        let inset = DiveActivityOverviewPanelMetrics.mediaCarouselScreenAlignmentTopInset(
            layoutHeight: layoutHeight,
            detent: detent
        )
        return inset + carouselRowHeight
    }

    /// Inset under the **medium** Media carousel so thumbnails sit near the sheet’s bottom edge.
    nonisolated static let mediumCarouselBottomPadding: CGFloat = 8

    /// **Medium** Media pins the carousel to the bottom of the overview panel (not the minimized slot).
    nonisolated static func pinsMediaCarouselToSheetBottom(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .large
    }

    /// **Media** panel outer scroll stays off — **large** scrolls inside the pinned chrome host.
    nonisolated static func disablesPanelScroll(
        isMediaTabSelected: Bool,
        detent: DiveActivityOverviewDetent
    ) -> Bool {
        _ = detent
        return isMediaTabSelected
    }

    /// Base carousel preview size (~60% of the former **72 pt** thumbnails).
    nonisolated static let carouselThumbnailSize: CGFloat = 43.2
    nonisolated static let carouselSelectedThumbnailScale: CGFloat = 1.4

    nonisolated static func carouselThumbnailExtent(isSelected: Bool) -> CGFloat {
        isSelected
            ? carouselThumbnailSize * carouselSelectedThumbnailScale
            : carouselThumbnailSize
    }

    /// Square preview on logbook activity rows (trailing).
    /// Fallback square extent before the logbook row measures its text column.
    nonisolated static let logbookRowMediaPreviewMinExtent: CGFloat = 48
    nonisolated static let logbookRowMediaPreviewCornerRadius: CGFloat = 6
    nonisolated static let carouselThumbnailSpacing: CGFloat = 6
    nonisolated static let carouselThumbnailCornerRadius: CGFloat = 10
    /// Fixed row height so the carousel lays out inside the overview panel's vertical **`ScrollView`**.
    nonisolated static var carouselRowHeight: CGFloat {
        carouselThumbnailExtent(isSelected: true) + 4
    }

    nonisolated static let captureDateUnknownMessage = "Capture date unavailable"

    @MainActor
    static func selectedMedia<T: ActivityOverviewGalleryMedia>(
        selectedID: UUID?,
        in photos: [T]
    ) -> T? {
        guard let resolvedID = resolvedSelectedPhotoID(selectedID: selectedID, in: photos) else { return nil }
        return photos.first { $0.id == resolvedID }
    }

    @MainActor
    static func mediaPositionLabel(selectedID: UUID?, in photos: [DiveMediaPhoto]) -> String? {
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
        formattedCapturedAtGallery(media, timeZoneOffsetSeconds: timeZoneOffsetSeconds)
    }

    static func formattedCapturedAtGallery(
        _ media: some ActivityOverviewGalleryMedia,
        timeZoneOffsetSeconds: Int?
    ) -> String? {
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
        media: some ActivityOverviewGalleryMedia,
        captureContext: DiveMediaCaptureContext?,
        timeZoneOffsetSeconds: Int?,
        displayUnits: DiveDisplayUnitSystem
    ) -> (dateTimeLine: String, divePositionLine: String?)? {
        guard let dateTimeLine = formattedCapturedAtGallery(media, timeZoneOffsetSeconds: timeZoneOffsetSeconds) else {
            return nil
        }
        let divePositionLine = captureContext.map {
            formattedCaptureAtDivePosition(context: $0, displayUnits: displayUnits)
        }
        return (dateTimeLine, divePositionLine)
    }

    static func mediaPreviewCaptureAccessibilityLabel(
        media: some ActivityOverviewGalleryMedia,
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

    @MainActor
    static func nextSortOrder(on activity: DiveActivity) -> Int {
        let orders = activity.mediaPhotos.map(\.sortOrder)
        return (orders.max() ?? -1) + 1
    }

    /// Keeps pager selection valid when the photo list changes.
    /// Preserves a pending **`selectedID`** while **`photos`** is still empty (e.g. Home featured-media deep link before derived media loads).
    /// When **`preferredID`** is present in **`photos`**, it wins (Home / logbook deep link).
    @MainActor
    static func resolvedSelectedPhotoID<T: ActivityOverviewGalleryMedia>(
        selectedID: UUID?,
        in photos: [T],
        preferredID: UUID? = nil
    ) -> UUID? {
        guard !photos.isEmpty else { return preferredID ?? selectedID }
        if let preferredID, photos.contains(where: { $0.id == preferredID }) {
            return preferredID
        }
        if let selectedID, photos.contains(where: { $0.id == selectedID }) {
            return selectedID
        }
        return photos.first?.id
    }

    /// Index offset from the resolved selection (**`+1`** = next item in gallery order).
    @MainActor
    static func adjacentPhotoID(
        selectedID: UUID?,
        in photos: [DiveMediaPhoto],
        offset: Int
    ) -> UUID? {
        guard offset != 0,
              let resolvedID = resolvedSelectedPhotoID(selectedID: selectedID, in: photos),
              let index = photos.firstIndex(where: { $0.id == resolvedID })
        else { return nil }

        let nextIndex = index + offset
        guard photos.indices.contains(nextIndex) else { return nil }
        return photos[nextIndex].id
    }

    /// PhotoKit request edge for full-bleed pager photos — screen pixel width, clamped for memory.
    nonisolated static func fullScreenImageTargetEdge(screenPixelWidth: CGFloat) -> CGFloat {
        min(max(max(screenPixelWidth, 1), 800), 2_048)
    }

    /// Second reaffirm after viewport resize — **`ScrollView`** paging can settle one frame late on rotation.
    nonisolated static let pagerLayoutReaffirmSettleDelay: Duration = .milliseconds(120)

    /// Whether the media hero pager should realign its scroll target after a layout change.
    nonisolated static func shouldReaffirmPagerAfterViewportChange(
        previousSize: CGSize?,
        newSize: CGSize
    ) -> Bool {
        guard let previousSize else { return false }
        return previousSize != newSize
    }
}

/// Fish / buddy overview mode on dive Media **large** detent.
enum DiveActivityMediaLargeDetentMode: String, CaseIterable, Hashable, Identifiable, Sendable {
    case marineLife
    case buddies

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .marineLife: "fish.fill"
        case .buddies: "person.2.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .marineLife: "Marine life"
        case .buddies: "Buddies"
        }
    }

    var addTagsAccessibilityLabel: String {
        switch self {
        case .marineLife: "Tag more marine life"
        case .buddies: "Tag more buddies"
        }
    }

    var addTagsAccessibilityIdentifier: String {
        switch self {
        case .marineLife: "DiveOverview.MediaLargeAddMarineLifeTag"
        case .buddies: "DiveOverview.MediaLargeAddBuddyTag"
        }
    }
}
