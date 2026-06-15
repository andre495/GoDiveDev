import SwiftUI

/// Trip overview media — rounded preview; drag up/down to browse with the frame following the finger.
struct TripDetailMediaGallerySection: View {
    let mediaItems: [DiveMediaPhoto]
    let timeZoneOffsetByMediaID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    let sightings: [SightingInstance]
    let marineLifeCatalog: [MarineLife]
    let ownerProfileID: UUID?
    var initialSelectedMediaID: UUID?
    var onOpenDive: (UUID) -> Void
    var onOpenInDive: (UUID, UUID) -> Void

    @State private var selectedMediaID: UUID?
    @State private var browseDragTranslation: CGFloat = 0
    @State private var showsMarineLifeOverlay = false
    @State private var selectedTaggedSpeciesUUID: String?
    @State private var didApplyInitialMediaSelection = false

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
        }
        .onChange(of: selectedMediaID) { _, _ in
            closeMarineLifeOverlay()
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
        let adjacentMedia = adjacentMedia(forBrowseStep: browseStep)

        ZStack {
            if let adjacentMedia, browseDragTranslation != 0 {
                mediaItemView(for: adjacentMedia)
                    .offset(
                        y: TripDetailMediaGalleryPresentation.adjacentItemOffset(
                            verticalTranslation: browseDragTranslation,
                            previewHeight: previewSize.height
                        )
                    )
                    .scaleEffect(TripDetailMediaGalleryPresentation.interactiveAdjacentScale(progress: progress))
                    .opacity(TripDetailMediaGalleryPresentation.interactiveAdjacentOpacity(progress: progress))
            }

            if let selectedMedia {
                mediaItemView(for: selectedMedia)
                    .offset(y: browseDragTranslation)
                    .scaleEffect(TripDetailMediaGalleryPresentation.interactiveCurrentScale(progress: progress))
                    .opacity(TripDetailMediaGalleryPresentation.interactiveCurrentOpacity(progress: progress))
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
    private func mediaItemView(for media: DiveMediaPhoto) -> some View {
        DiveActivityMediaItemView(
            media: media,
            timeZoneOffsetSeconds: timeZoneOffsetByMediaID[media.id] ?? nil,
            showsCaptureDateOverlay: !showsMarineLifeOverlay,
            isVideoPlaybackActive: media.resolvedMediaKind == .video && !showsMarineLifeOverlay,
            loopsVideoPlayback: true
        )
        .id(media.id)
    }

    @ViewBuilder
    private func mediaOverlayChrome(previewSize: CGSize, cornerRadius: CGFloat) -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                    Color.clear
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)

                    Spacer(minLength: 0)

                    if let positionLabel = TripDetailMediaGalleryPresentation.mediaPositionLabel(
                        selectedID: selectedMediaID,
                        in: mediaItems
                    ) {
                        Text(positionLabel)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .accessibilityHidden(true)
                    }
                }

                Spacer(minLength: 0)
            }
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                    openOnDiveButton

                    Spacer(minLength: 0)
                        .allowsHitTesting(false)
                }

                Spacer(minLength: 0)
                    .allowsHitTesting(false)

                HStack {
                    Spacer(minLength: 0)
                        .allowsHitTesting(false)

                    if showsMarineLifeTagIndicator {
                        marineLifeTagButton
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .frame(width: previewSize.width, height: previewSize.height, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
            Label(DiveTripPresentation.tripMediaOpenOnDiveButtonTitle, systemImage: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
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
}

private struct TripDetailMediaGallerySelectionSignature: Equatable {
    var count: Int
    var firstID: UUID?
    var lastID: UUID?
}
