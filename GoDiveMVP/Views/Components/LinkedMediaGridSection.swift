import SwiftUI

/// 3-column linked media grid; tap opens **`LinkedMediaFullscreenView`**.
struct LinkedMediaGridSection: View {
    let mediaItems: [DiveMediaPhoto]
    let timeZoneOffsetByMediaID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    @Binding var gallerySelectedMediaID: UUID?
    let featuredMediaPhotoID: UUID?
    let onToggleFeaturedTaggedMedia: (() -> Void)?
    let sightings: [SightingInstance]
    let marineLifeCatalog: [MarineLife]
    let ownerProfileID: UUID?
    /// When non-`nil`, badge lookups use this set only (O(1)). When `nil`, fall back to model / sightings scans.
    var buddyTaggedMediaIDs: Set<UUID>? = nil
    var marineLifeTaggedMediaIDs: Set<UUID>? = nil
    /// Optional Home-style tag counts for corner count capsules. When `nil`, counts are derived from models.
    var buddyTagCountByMediaID: [UUID: Int]? = nil
    var marineLifeTagCountByMediaID: [UUID: Int]? = nil
    /// When true, use soft stored JPEG only (no PhotoKit). Prefer false for sharper grid tiles (soft first, then upgrade).
    var prefersStoredPreviewThumbnails: Bool = false
    let fullscreenConfiguration: LinkedMediaFullscreenView.Configuration
    let gridAccessibilityIdentifier: String
    let gridItemAccessibilityPrefix: String
    let sectionAccessibilityIdentifier: String
    let emptyMessage: String?
    let emptyAccessibilityIdentifier: String?
    var initialFullscreenMediaID: UUID?
    /// When true (e.g. an interactive back-swipe is in progress), thumbnail taps are ignored so the
    /// gesture cannot inadvertently open a media item. Matches the search result-row freeze behavior.
    var isSelectionBlocked: Bool = false
    /// When false, the grid only reports selection via **`gallerySelectedMediaID`** / **`onSelectMedia`**
    /// and the parent owns the fullscreen cover (e.g. sectioned Search → Media with one cross-month pager).
    var presentsFullscreenCover: Bool = true
    var onSelectMedia: ((UUID) -> Void)? = nil
    /// Opens fullscreen with the dive Media **large**-detent overview (fish or buddy mode).
    var onSelectMediaTagOverview: ((UUID, DiveActivityMediaLargeDetentMode) -> Void)? = nil
    let onOpenDive: (UUID) -> Void

    @State private var fullscreenMediaSelection: LinkedMediaGridFullscreenSelection?
    @State private var didApplyInitialFullscreenSelection = false

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: LinkedMediaGridPresentation.spacing),
            count: LinkedMediaGridPresentation.columnCount
        )
    }

    var body: some View {
        Group {
            if mediaItems.isEmpty, let emptyMessage {
                Text(emptyMessage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(emptyAccessibilityIdentifier ?? "LinkedMedia.Grid.Empty")
            } else {
                LazyVGrid(
                    columns: gridColumns,
                    spacing: LinkedMediaGridPresentation.spacing
                ) {
                    ForEach(mediaItems, id: \.id) { media in
                        gridCellButton(for: media)
                    }
                }
                .accessibilityIdentifier(gridAccessibilityIdentifier)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(sectionAccessibilityIdentifier)
        .modifier(LinkedMediaGridFullscreenCoverGate(
            isEnabled: presentsFullscreenCover,
            selection: $fullscreenMediaSelection,
            mediaItems: mediaItems,
            timeZoneOffsetByMediaID: timeZoneOffsetByMediaID,
            linkedMediaItems: linkedMediaItems,
            gallerySelectedMediaID: $gallerySelectedMediaID,
            configuration: fullscreenConfiguration,
            featuredMediaPhotoID: featuredMediaPhotoID,
            onToggleFeatured: onToggleFeaturedTaggedMedia,
            sightings: sightings,
            marineLifeCatalog: marineLifeCatalog,
            ownerProfileID: ownerProfileID,
            onOpenDive: onOpenDive
        ))
        .onAppear(perform: applyInitialFullscreenSelectionIfNeeded)
        .onChange(of: initialFullscreenMediaID) { _, _ in
            didApplyInitialFullscreenSelection = false
            applyInitialFullscreenSelectionIfNeeded()
        }
        .onChange(of: mediaItems.count) { _, _ in
            didApplyInitialFullscreenSelection = false
            applyInitialFullscreenSelectionIfNeeded()
        }
    }

    private func applyInitialFullscreenSelectionIfNeeded() {
        guard presentsFullscreenCover,
              !didApplyInitialFullscreenSelection,
              let initialFullscreenMediaID,
              mediaItems.contains(where: { $0.id == initialFullscreenMediaID })
        else { return }

        gallerySelectedMediaID = initialFullscreenMediaID
        fullscreenMediaSelection = LinkedMediaGridFullscreenSelection(id: initialFullscreenMediaID)
        didApplyInitialFullscreenSelection = true
    }

    private func gridCellButton(for media: DiveMediaPhoto) -> some View {
        Button {
            guard !isSelectionBlocked else { return }
            openFullscreen(mediaID: media.id, tagOverviewMode: nil)
        } label: {
            gridCellThumbnail(for: media)
        }
        .buttonStyle(.plain)
        .disabled(isSelectionBlocked)
        .overlay {
            gridCellTagBadges(for: media)
        }
        .accessibilityLabel(gridCellAccessibilityLabel(for: media))
        .accessibilityIdentifier("\(gridItemAccessibilityPrefix).\(media.id.uuidString)")
    }

    private func openFullscreen(
        mediaID: UUID,
        tagOverviewMode: DiveActivityMediaLargeDetentMode?
    ) {
        gallerySelectedMediaID = mediaID
        if presentsFullscreenCover {
            fullscreenMediaSelection = LinkedMediaGridFullscreenSelection(
                id: mediaID,
                tagOverviewMode: tagOverviewMode
            )
        } else if let tagOverviewMode {
            onSelectMediaTagOverview?(mediaID, tagOverviewMode)
        } else {
            onSelectMedia?(mediaID)
        }
    }

    private func gridCellThumbnail(for media: DiveMediaPhoto) -> some View {
        Color.clear
            .aspectRatio(LinkedMediaGridPresentation.cellAspectRatio, contentMode: .fit)
            .overlay {
                DiveActivityMediaThumbnailView(
                    media: media,
                    size: 0,
                    cornerRadius: 0,
                    prefersStoredPreviewOnly: prefersStoredPreviewThumbnails
                )
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: LinkedMediaGridPresentation.cornerRadius,
                    style: .continuous
                )
            )
            .overlay(alignment: .topTrailing) {
                if media.id == featuredMediaPhotoID {
                    featuredBadge
                        .padding(6)
                }
            }
    }

    private func gridCellTagBadges(for media: DiveMediaPhoto) -> some View {
        Color.clear
            .aspectRatio(LinkedMediaGridPresentation.cellAspectRatio, contentMode: .fit)
            .linkedMediaGridTagBadges(
                buddyTagCount: buddyTagCount(for: media.id),
                marineLifeTagCount: marineLifeTagCount(for: media.id),
                onBuddyTap: {
                    guard !isSelectionBlocked else { return }
                    openFullscreen(
                        mediaID: media.id,
                        tagOverviewMode: LinkedMediaGridPresentation.tagOverviewMode(isBuddyBadge: true)
                    )
                },
                onMarineLifeTap: {
                    guard !isSelectionBlocked else { return }
                    openFullscreen(
                        mediaID: media.id,
                        tagOverviewMode: LinkedMediaGridPresentation.tagOverviewMode(isBuddyBadge: false)
                    )
                }
            )
            .allowsHitTesting(
                LinkedMediaGridPresentation.showsTagIcon(hasTags: hasBuddyTags(for: media.id))
                    || LinkedMediaGridPresentation.showsTagIcon(hasTags: hasMarineLifeTags(for: media.id))
            )
    }

    private var featuredBadge: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(4)
            .background {
                Circle()
                    .fill(AppTheme.Colors.accent)
            }
            .accessibilityHidden(true)
    }

    private func hasMarineLifeTags(for mediaID: UUID) -> Bool {
        marineLifeTagCount(for: mediaID) > 0
    }

    private func hasBuddyTags(for mediaID: UUID) -> Bool {
        buddyTagCount(for: mediaID) > 0
    }

    private func marineLifeTagCount(for mediaID: UUID) -> Int {
        if let marineLifeTagCountByMediaID {
            return marineLifeTagCountByMediaID[mediaID] ?? 0
        }
        let fromSightings = TripDetailMediaGalleryPresentation.taggedSpecies(
            mediaID: mediaID,
            sightings: sightings,
            catalog: marineLifeCatalog
        ).count
        if fromSightings > 0 { return fromSightings }
        if let marineLifeTaggedMediaIDs {
            return marineLifeTaggedMediaIDs.contains(mediaID) ? 1 : 0
        }
        return 0
    }

    private func buddyTagCount(for mediaID: UUID) -> Int {
        if let buddyTagCountByMediaID {
            return buddyTagCountByMediaID[mediaID] ?? 0
        }
        if let media = mediaItems.first(where: { $0.id == mediaID }),
           let dive = media.dive
        {
            let fromTags = DiveMediaBuddyTagPresentation.resolvedTaggedBuddies(
                mediaPhotoID: mediaID,
                tags: dive.mediaBuddyTags
            ).count
            if fromTags > 0 { return fromTags }
        }
        if let buddyTaggedMediaIDs {
            return buddyTaggedMediaIDs.contains(mediaID) ? 1 : 0
        }
        return 0
    }

    private func gridCellAccessibilityLabel(for media: DiveMediaPhoto) -> String {
        let kind = media.resolvedMediaKind == .video ? "Video" : "Photo"
        var parts = [kind]
        if media.id == featuredMediaPhotoID {
            parts = ["Featured \(kind.lowercased())"]
        }
        if hasMarineLifeTags(for: media.id) {
            parts.append("marine life tagged")
        }
        if hasBuddyTags(for: media.id) {
            parts.append("buddies tagged")
        }
        return parts.joined(separator: ", ")
    }
}

private struct LinkedMediaGridFullscreenSelection: Identifiable {
    let id: UUID
    var tagOverviewMode: DiveActivityMediaLargeDetentMode? = nil
}

/// Avoids mounting **`fullScreenCover`** when the parent already owns fullscreen presentation.
private struct LinkedMediaGridFullscreenCoverGate: ViewModifier {
    let isEnabled: Bool
    @Binding var selection: LinkedMediaGridFullscreenSelection?
    let mediaItems: [DiveMediaPhoto]
    let timeZoneOffsetByMediaID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    @Binding var gallerySelectedMediaID: UUID?
    let configuration: LinkedMediaFullscreenView.Configuration
    let featuredMediaPhotoID: UUID?
    let onToggleFeatured: (() -> Void)?
    let sightings: [SightingInstance]
    let marineLifeCatalog: [MarineLife]
    let ownerProfileID: UUID?
    let onOpenDive: (UUID) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.fullScreenCover(item: $selection) { item in
                LinkedMediaFullscreenView(
                    mediaItems: mediaItems,
                    timeZoneOffsetByMediaID: timeZoneOffsetByMediaID,
                    linkedMediaItems: linkedMediaItems,
                    selectedMediaID: $gallerySelectedMediaID,
                    configuration: configuration,
                    featuredMediaPhotoID: featuredMediaPhotoID,
                    onToggleFeatured: onToggleFeatured,
                    sightings: sightings,
                    marineLifeCatalog: marineLifeCatalog,
                    ownerProfileID: ownerProfileID,
                    initialTagOverviewMode: item.tagOverviewMode,
                    onOpenDive: onOpenDive
                )
                .onAppear {
                    gallerySelectedMediaID = item.id
                }
            }
        } else {
            content
        }
    }
}

extension View {
    /// Buddy (leading) + fish (trailing) corner icons when that media has tags of that kind.
    /// Count capsule appears when **`showsTagCountBadge`** (**count > 1**).
    func linkedMediaGridTagBadges(
        buddyTagCount: Int,
        marineLifeTagCount: Int,
        onBuddyTap: (() -> Void)? = nil,
        onMarineLifeTap: (() -> Void)? = nil
    ) -> some View {
        overlay(alignment: .bottomLeading) {
            if LinkedMediaGridPresentation.showsTagIcon(hasTags: buddyTagCount > 0) {
                LinkedMediaGridTagBadge(
                    systemName: "person.2.fill",
                    tagCount: buddyTagCount,
                    accessibilityLabel: LinkedMediaGridPresentation.showsTagCountBadge(tagCount: buddyTagCount)
                        ? "\(buddyTagCount) buddies"
                        : "Buddies",
                    action: onBuddyTap
                )
                .padding(LinkedMediaGridPresentation.tagIconEdgePadding)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if LinkedMediaGridPresentation.showsTagIcon(hasTags: marineLifeTagCount > 0) {
                LinkedMediaGridTagBadge(
                    systemName: "fish.fill",
                    tagCount: marineLifeTagCount,
                    accessibilityLabel: LinkedMediaGridPresentation.showsTagCountBadge(tagCount: marineLifeTagCount)
                        ? "\(marineLifeTagCount) marine life"
                        : "Marine life",
                    action: onMarineLifeTap
                )
                .padding(LinkedMediaGridPresentation.tagIconEdgePadding)
            }
        }
    }

    /// Compatibility for call sites that only know presence (count treated as **1** when tagged).
    func linkedMediaGridTagBadges(
        hasBuddyTags: Bool,
        hasMarineLifeTags: Bool,
        onBuddyTap: (() -> Void)? = nil,
        onMarineLifeTap: (() -> Void)? = nil
    ) -> some View {
        linkedMediaGridTagBadges(
            buddyTagCount: hasBuddyTags ? 1 : 0,
            marineLifeTagCount: hasMarineLifeTags ? 1 : 0,
            onBuddyTap: onBuddyTap,
            onMarineLifeTap: onMarineLifeTap
        )
    }
}

private struct LinkedMediaGridTagBadge: View {
    let systemName: String
    var tagCount: Int = 0
    var accessibilityLabel: String = ""
    var action: (() -> Void)? = nil

    var body: some View {
        let icon = ZStack(alignment: .topTrailing) {
            Image(systemName: systemName)
                .font(.system(size: LinkedMediaGridPresentation.tagIconPointSize, weight: .bold))
                .foregroundStyle(AppTheme.Colors.accent)
                .padding(LinkedMediaGridPresentation.tagIconPadding)
                .background {
                    Circle()
                        .fill(.black.opacity(0.42))
                }

            if LinkedMediaGridPresentation.showsTagCountBadge(tagCount: tagCount) {
                MediaTagCountBadge(
                    count: tagCount,
                    offsetX: MediaTagCountBadgePresentation.gridOffsetX,
                    offsetY: MediaTagCountBadgePresentation.gridOffsetY
                )
            }
        }

        if let action {
            Button(action: action) {
                icon
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        } else {
            icon
                .accessibilityHidden(true)
        }
    }
}
