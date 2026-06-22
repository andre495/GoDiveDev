import SwiftUI

/// Trip overview media — rounded preview; drag up/down to browse with the frame following the finger.
struct TripDetailMediaGallerySection: View {
    private enum PreloadedMediaRole {
        case previous
        case selected
        case next
    }

    let mediaItems: [DiveMediaPhoto]
    let timeZoneOffsetByMediaID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    let sightings: [SightingInstance]
    let marineLifeCatalog: [MarineLife]
    let ownerProfileID: UUID?
    var initialSelectedMediaID: UUID?
    var onOpenDive: (UUID) -> Void
    var onOpenInDive: (UUID, UUID) -> Void

    @Environment(\.displayScale) private var displayScale

    @State private var selectedMediaID: UUID?
    @State private var browseDragTranslation: CGFloat = 0
    @State private var showsMarineLifeOverlay = false
    @State private var selectedTaggedSpeciesUUID: String?
    @State private var didApplyInitialMediaSelection = false
    @State private var lastKnownPreviewPixelWidth: CGFloat = 0

    private var selectedMedia: DiveMediaPhoto? {
        DiveActivityMediaPresentation.selectedMedia(selectedID: selectedMediaID, in: mediaItems)
    }

    private var selectedMediaTaggedSpecies: [MarineLife] {
        TripDetailMediaGalleryPresentation.taggedSpecies(
            mediaID: selectedMediaID,
            sightings: sightings,
            catalog: marineLifeCatalog
        )
    }

    private var showsMarineLifeTagIndicator: Bool {
        TripDetailMediaGalleryPresentation.showsMarineLifeTagIndicator(
            mediaID: selectedMediaID,
            sightings: sightings
        )
    }

    private var canBrowseForward: Bool {
        DiveActivityMediaPresentation.adjacentPhotoID(
            selectedID: selectedMediaID,
            in: mediaItems,
            offset: 1
        ) != nil
    }

    private var canBrowseBackward: Bool {
        DiveActivityMediaPresentation.adjacentPhotoID(
            selectedID: selectedMediaID,
            in: mediaItems,
            offset: -1
        ) != nil
    }

    private var mediaIDsSignature: TripDetailMediaGallerySelectionSignature {
        TripDetailMediaGallerySelectionSignature(
            count: mediaItems.count,
            firstID: mediaItems.first?.id,
            lastID: mediaItems.last?.id
        )
    }

    var body: some View {
        Group {
            if mediaItems.isEmpty {
                Text(DiveTripPresentation.tripMediaEmptyMessage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .accessibilityIdentifier("TripDetail.Media.Empty")
            } else {
                GeometryReader { geometry in
                    mediaPreview(containerSize: geometry.size)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("TripDetail.MediaSection")
        .onAppear(perform: syncSelectionToMedia)
        .onChange(of: mediaIDsSignature) { _, _ in
            syncSelectionToMedia()
            prefetchProgressiveNeighbors()
        }
        .onChange(of: selectedMediaID) { _, _ in
            closeMarineLifeOverlay()
            prefetchProgressiveNeighbors()
        }
    }

    @ViewBuilder
    private func mediaPreview(containerSize: CGSize) -> some View {
        let previewSize = TripDetailMediaGalleryPresentation.previewSize(in: containerSize)
        let cornerRadius = TripDetailMediaGalleryPresentation.previewCornerRadius

        ZStack {
            Group {
                if showsMarineLifeOverlay {
                    mediaPreviewContent(previewSize: previewSize, cornerRadius: cornerRadius)
                } else {
                    mediaPreviewContent(previewSize: previewSize, cornerRadius: cornerRadius)
                        .highPriorityGesture(browseGesture(previewHeight: previewSize.height))
                }
            }

            if showsMarineLifeOverlay, !selectedMediaTaggedSpecies.isEmpty {
                TripDetailMediaMarineLifeOverlay(
                    taggedSpecies: selectedMediaTaggedSpecies,
                    previewSize: previewSize,
                    cornerRadius: cornerRadius,
                    ownerProfileID: ownerProfileID,
                    selectedSpeciesUUID: $selectedTaggedSpeciesUUID,
                    onOpenDive: onOpenDive,
                    onClose: closeMarineLifeOverlay
                )
                .transition(overlayTransition)
            }

            if !showsMarineLifeOverlay {
                mediaOverlayChrome(previewSize: previewSize, cornerRadius: cornerRadius)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height, alignment: .top)
        .animation(overlayAnimation, value: showsMarineLifeOverlay)
        .onAppear {
            lastKnownPreviewPixelWidth = previewSize.width * displayScale
            prefetchProgressiveNeighbors()
        }
        .onChange(of: previewSize.width) { _, newWidth in
            lastKnownPreviewPixelWidth = newWidth * displayScale
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("TripDetail.Media.Preview")
    }

    @ViewBuilder
    private func mediaPreviewContent(previewSize: CGSize, cornerRadius: CGFloat) -> some View {
        let progress = TripDetailMediaGalleryPresentation.interactiveBrowseProgress(
            verticalTranslation: browseDragTranslation,
            previewHeight: previewSize.height
        )
        let browseStep = TripDetailMediaGalleryPresentation.interactiveBrowseStep(
            forVerticalTranslation: browseDragTranslation
        )
        ZStack {
            if let previousMedia = adjacentMedia(forBrowseStep: -1) {
                mountedMediaLayer(
                    for: previousMedia,
                    previewSize: previewSize,
                    role: .previous,
                    progress: progress,
                    browseStep: browseStep
                )
            }

            if let nextMedia = adjacentMedia(forBrowseStep: 1) {
                mountedMediaLayer(
                    for: nextMedia,
                    previewSize: previewSize,
                    role: .next,
                    progress: progress,
                    browseStep: browseStep
                )
            }

            if let selectedMedia {
                mountedMediaLayer(
                    for: selectedMedia,
                    previewSize: previewSize,
                    role: .selected,
                    progress: progress,
                    browseStep: browseStep
                )
            } else {
                AppTheme.Colors.tabUnselected.opacity(0.12)
            }
        }
        .frame(width: previewSize.width, height: previewSize.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(browseAccessibilityLabel)
        .accessibilityAddTraits(.allowsDirectInteraction)
        .accessibilityHint("Swipe up for next, swipe down for previous.")
        .accessibilityAction(named: "Next") {
            advanceMedia(offset: 1, previewHeight: previewSize.height)
        }
        .accessibilityAction(named: "Previous") {
            advanceMedia(offset: -1, previewHeight: previewSize.height)
        }
    }

    @ViewBuilder
    private func mountedMediaLayer(
        for media: DiveMediaPhoto,
        previewSize: CGSize,
        role: PreloadedMediaRole,
        progress: CGFloat,
        browseStep: Int?
    ) -> some View {
        let isInteractiveBrowse = browseDragTranslation != 0
        let showsAdjacentDuringBrowse = isInteractiveBrowse
            && ((role == .next && browseStep == 1) || (role == .previous && browseStep == -1))

        mediaItemView(
            for: media,
            isVideoPlaybackActive: isVideoPlaybackActive(for: media)
        )
        .offset(
            y: mountedMediaOffsetY(
                role: role,
                previewHeight: previewSize.height,
                showsAdjacentDuringBrowse: showsAdjacentDuringBrowse
            )
        )
        .scaleEffect(
            mountedMediaScale(
                role: role,
                progress: progress,
                isInteractiveBrowse: isInteractiveBrowse,
                showsAdjacentDuringBrowse: showsAdjacentDuringBrowse
            )
        )
        .opacity(
            mountedMediaOpacity(
                role: role,
                progress: progress,
                isInteractiveBrowse: isInteractiveBrowse,
                showsAdjacentDuringBrowse: showsAdjacentDuringBrowse
            )
        )
        .allowsHitTesting(role == .selected && !isInteractiveBrowse)
        .zIndex(role == .selected ? 1 : 0)
    }

    @ViewBuilder
    private func mediaItemView(for media: DiveMediaPhoto, isVideoPlaybackActive: Bool) -> some View {
        DiveActivityMediaItemView(
            media: media,
            timeZoneOffsetSeconds: timeZoneOffsetByMediaID[media.id] ?? nil,
            showsCaptureDateOverlay: !showsMarineLifeOverlay,
            isVideoPlaybackActive: isVideoPlaybackActive,
            loopsVideoPlayback: true
        )
        .id(media.id)
    }

    private func isVideoPlaybackActive(for media: DiveMediaPhoto) -> Bool {
        media.resolvedMediaKind == .video
            && !showsMarineLifeOverlay
            && media.id == selectedMediaID
            && browseDragTranslation == 0
    }

    private func mountedMediaOpacity(
        role: PreloadedMediaRole,
        progress: CGFloat,
        isInteractiveBrowse: Bool,
        showsAdjacentDuringBrowse: Bool
    ) -> Double {
        switch role {
        case .selected:
            if isInteractiveBrowse {
                return TripDetailMediaGalleryPresentation.interactiveCurrentOpacity(progress: progress)
            }
            return 1
        case .previous, .next:
            if showsAdjacentDuringBrowse {
                return TripDetailMediaGalleryPresentation.interactiveAdjacentOpacity(progress: progress)
            }
            return 0
        }
    }

    private func mountedMediaScale(
        role: PreloadedMediaRole,
        progress: CGFloat,
        isInteractiveBrowse: Bool,
        showsAdjacentDuringBrowse: Bool
    ) -> CGFloat {
        switch role {
        case .selected:
            if isInteractiveBrowse {
                return TripDetailMediaGalleryPresentation.interactiveCurrentScale(progress: progress)
            }
            return 1
        case .previous, .next:
            if showsAdjacentDuringBrowse {
                return TripDetailMediaGalleryPresentation.interactiveAdjacentScale(progress: progress)
            }
            return 1
        }
    }

    private func mountedMediaOffsetY(
        role: PreloadedMediaRole,
        previewHeight: CGFloat,
        showsAdjacentDuringBrowse: Bool
    ) -> CGFloat {
        switch role {
        case .selected:
            return browseDragTranslation
        case .previous, .next:
            if showsAdjacentDuringBrowse {
                return TripDetailMediaGalleryPresentation.adjacentItemOffset(
                    verticalTranslation: browseDragTranslation,
                    previewHeight: previewHeight
                )
            }
            return 0
        }
    }

    @ViewBuilder
    private func mediaOverlayChrome(previewSize: CGSize, cornerRadius: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                openOnDiveButton

                Spacer(minLength: 0)

                if let positionLabel = TripDetailMediaGalleryPresentation.mediaPositionLabel(
                    selectedID: selectedMediaID,
                    in: mediaItems
                ) {
                    mediaOverlayChip {
                        Text(positionLabel)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityHidden(true)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer(minLength: 0)

                if showsMarineLifeTagIndicator {
                    marineLifeTagButton
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(width: previewSize.width, height: previewSize.height, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private func mediaOverlayChip<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, TripDetailMediaGalleryPresentation.overlayChipHorizontalPadding)
            .padding(.vertical, TripDetailMediaGalleryPresentation.overlayChipVerticalPadding)
            .background(
                .black.opacity(TripDetailMediaGalleryPresentation.overlayChipBackgroundOpacity),
                in: Capsule()
            )
    }

    private var marineLifeTagButton: some View {
        Button(action: toggleMarineLifeOverlay) {
            Image(systemName: "fish.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(.black.opacity(0.42))
                        .background {
                            Circle()
                                .fill(.ultraThinMaterial)
                        }
                        .clipShape(Circle())
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Marine life")
        .accessibilityHint("Shows species tagged on this photo")
        .accessibilityIdentifier("TripDetail.Media.MarineLifeTag")
    }

    private var overlayAnimation: Animation {
        .spring(response: 0.34, dampingFraction: 0.86)
    }

    private var overlayTransition: AnyTransition {
        .opacity
    }

    private var openOnDiveButton: some View {
        Button(action: openSelectedMediaInDive) {
            mediaOverlayChip {
                Label(DiveTripPresentation.tripMediaOpenOnDiveButtonTitle, systemImage: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("TripDetail.Media.OpenOnDive")
    }

    private var browseAnimation: Animation {
        .spring(
            response: TripDetailMediaGalleryPresentation.browseAnimationDuration,
            dampingFraction: TripDetailMediaGalleryPresentation.browseAnimationDamping
        )
    }

    private var browseAccessibilityLabel: String {
        TripDetailMediaGalleryPresentation.browseAccessibilityLabel(
            itemCount: mediaItems.count,
            positionLabel: TripDetailMediaGalleryPresentation.mediaPositionLabel(
                selectedID: selectedMediaID,
                in: mediaItems
            ),
            hasTaggedMarineLife: showsMarineLifeTagIndicator
        )
    }

    private func browseGesture(previewHeight: CGFloat) -> some Gesture {
        DragGesture(
            minimumDistance: TripDetailMediaGalleryPresentation.swipeMinimumDistance,
            coordinateSpace: .local
        )
        .onChanged { value in
            guard abs(value.translation.height) > abs(value.translation.width) else { return }
            browseDragTranslation = TripDetailMediaGalleryPresentation.rubberBandedBrowseTranslation(
                value.translation.height,
                canBrowseForward: canBrowseForward,
                canBrowseBackward: canBrowseBackward
            )
        }
        .onEnded { value in
            guard abs(value.translation.height) > abs(value.translation.width) else {
                resetBrowseDrag()
                return
            }

            let translation = TripDetailMediaGalleryPresentation.rubberBandedBrowseTranslation(
                value.translation.height,
                canBrowseForward: canBrowseForward,
                canBrowseBackward: canBrowseBackward
            )

            if let step = TripDetailMediaGalleryPresentation.browseOffset(
                forVerticalTranslation: translation
            ), adjacentMedia(forBrowseStep: step) != nil {
                commitBrowse(step: step, previewHeight: previewHeight)
            } else {
                resetBrowseDrag()
            }
        }
    }

    private func adjacentMedia(forBrowseStep step: Int?) -> DiveMediaPhoto? {
        guard let step,
              let adjacentID = DiveActivityMediaPresentation.adjacentPhotoID(
                selectedID: selectedMediaID,
                in: mediaItems,
                offset: step
              )
        else { return nil }

        return mediaItems.first(where: { $0.id == adjacentID })
    }

    private func resetBrowseDrag() {
        withAnimation(browseAnimation) {
            browseDragTranslation = 0
        }
    }

    private func commitBrowse(step: Int, previewHeight: CGFloat) {
        guard let nextID = DiveActivityMediaPresentation.adjacentPhotoID(
            selectedID: selectedMediaID,
            in: mediaItems,
            offset: step
        ) else {
            resetBrowseDrag()
            return
        }

        withAnimation(browseAnimation) {
            browseDragTranslation = TripDetailMediaGalleryPresentation.interactiveCommitTranslation(
                step: step,
                previewHeight: previewHeight
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + TripDetailMediaGalleryPresentation.browseAnimationDuration) {
            selectedMediaID = nextID
            browseDragTranslation = 0
        }
    }

    private func advanceMedia(offset: Int, previewHeight: CGFloat) {
        guard adjacentMedia(forBrowseStep: offset) != nil else { return }
        commitBrowse(step: offset, previewHeight: previewHeight)
    }

    private func syncSelectionToMedia() {
        if !didApplyInitialMediaSelection,
           let initialSelectedMediaID,
           let resolvedInitial = DiveActivityMediaPresentation.resolvedSelectedPhotoID(
            selectedID: initialSelectedMediaID,
            in: mediaItems
           ) {
            selectedMediaID = resolvedInitial
            didApplyInitialMediaSelection = true
            return
        }

        selectedMediaID = DiveActivityMediaPresentation.resolvedSelectedPhotoID(
            selectedID: selectedMediaID,
            in: mediaItems
        )
    }

    private func openSelectedMediaInDive() {
        guard let selectedMediaID,
              let diveID = TripDetailMediaPresentation.diveActivityID(
                for: selectedMediaID,
                in: linkedMediaItems
              )
        else { return }
        onOpenInDive(diveID, selectedMediaID)
    }

    private func toggleMarineLifeOverlay() {
        withAnimation(overlayAnimation) {
            if showsMarineLifeOverlay {
                showsMarineLifeOverlay = false
                selectedTaggedSpeciesUUID = nil
            } else {
                selectedTaggedSpeciesUUID = selectedMediaTaggedSpecies.first?.uuid
                showsMarineLifeOverlay = true
            }
        }
    }

    private func closeMarineLifeOverlay() {
        guard showsMarineLifeOverlay else { return }
        withAnimation(overlayAnimation) {
            showsMarineLifeOverlay = false
            selectedTaggedSpeciesUUID = nil
        }
    }

    private func prefetchProgressiveNeighbors() {
        guard lastKnownPreviewPixelWidth > 0 else { return }
        DiveMediaProgressivePrefetch.warmNeighbors(
            mediaItems: mediaItems,
            selectedMediaID: selectedMediaID,
            screenPixelWidth: lastKnownPreviewPixelWidth,
            isMediaTabSelected: true
        )
    }
}

private struct TripDetailMediaGallerySelectionSignature: Equatable {
    var count: Int
    var firstID: UUID?
    var lastID: UUID?
}
