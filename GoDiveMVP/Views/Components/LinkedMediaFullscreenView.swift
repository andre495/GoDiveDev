import SwiftData
import SwiftUI

/// Full-screen linked media — horizontal browse, vertical dismiss, optional marine-life overlay.
struct LinkedMediaFullscreenView: View {
    struct Configuration: Sendable {
        let rootAccessibilityIdentifier: String
        let closeAccessibilityIdentifier: String
        let openOnDiveAccessibilityIdentifier: String
        let featureToggleAccessibilityIdentifier: String
        let marineLifeAccessibilityIdentifier: String
        let openOnDiveTitle: String
        let accessibilityContextLabel: String
        let showsMarineLifeTagButton: Bool
        let openOnDivePlacement: TripDetailMediaGalleryOverlayControls.OpenOnDivePlacement

        static let buddy = Configuration(
            rootAccessibilityIdentifier: "DiveBuddyDetails.TaggedMedia.Fullscreen",
            closeAccessibilityIdentifier: "DiveBuddyDetails.TaggedMedia.Fullscreen.Close",
            openOnDiveAccessibilityIdentifier: "DiveBuddyDetails.TaggedMedia.OpenOnDive",
            featureToggleAccessibilityIdentifier: "DiveBuddyDetails.TaggedMedia.FeatureToggle",
            marineLifeAccessibilityIdentifier: "DiveBuddyDetails.TaggedMedia.MarineLifeTag",
            openOnDiveTitle: DiveTripPresentation.tripMediaOpenOnDiveButtonTitle,
            accessibilityContextLabel: "Buddy tagged",
            showsMarineLifeTagButton: false,
            openOnDivePlacement: .trailing
        )

        static let trip = Configuration(
            rootAccessibilityIdentifier: "TripDetail.Media.Fullscreen",
            closeAccessibilityIdentifier: "TripDetail.Media.Fullscreen.Close",
            openOnDiveAccessibilityIdentifier: "TripDetail.Media.OpenOnDive",
            featureToggleAccessibilityIdentifier: "TripDetail.Media.FeatureToggle",
            marineLifeAccessibilityIdentifier: "TripDetail.Media.MarineLifeTag",
            openOnDiveTitle: DiveTripPresentation.tripMediaOpenOnDiveButtonTitle,
            accessibilityContextLabel: "Trip media",
            showsMarineLifeTagButton: true,
            openOnDivePlacement: .trailing
        )
    }

    private enum PreloadedMediaRole {
        case previous
        case selected
        case next
    }

    let mediaItems: [DiveMediaPhoto]
    let timeZoneOffsetByMediaID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    @Binding var selectedMediaID: UUID?
    let featuredMediaPhotoID: UUID?
    let onToggleFeatured: (() -> Void)?
    let sightings: [SightingInstance]
    let marineLifeCatalog: [MarineLife]
    let ownerProfileID: UUID?
    let configuration: Configuration
    let onOpenDive: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var horizontalDragTranslation: CGFloat = 0
    @State private var verticalDismissTranslation: CGFloat = 0
    @State private var lockedDragAxis: LinkedMediaFullscreenPresentation.DragAxis?
    @State private var containerHeight: CGFloat = 800
    @State private var showsMarineLifeOverlay = false
    @State private var selectedTaggedSpeciesUUID: String?
    @State private var linkedDivePresentation: LinkedDivePresentation?

    private struct LinkedDivePresentation: Identifiable {
        let diveID: UUID
        let mediaID: UUID

        var id: String {
            LinkedMediaFullscreenPresentation.linkedDiveCoverIdentity(
                diveID: diveID,
                mediaID: mediaID
            )
        }
    }

    init(
        mediaItems: [DiveMediaPhoto],
        timeZoneOffsetByMediaID: [UUID: Int?],
        linkedMediaItems: [TripDetailLinkedMediaItem],
        selectedMediaID: Binding<UUID?>,
        configuration: Configuration,
        featuredMediaPhotoID: UUID? = nil,
        onToggleFeatured: (() -> Void)? = nil,
        sightings: [SightingInstance] = [],
        marineLifeCatalog: [MarineLife] = [],
        ownerProfileID: UUID? = nil,
        onOpenDive: @escaping (UUID) -> Void = { _ in }
    ) {
        self.mediaItems = mediaItems
        self.timeZoneOffsetByMediaID = timeZoneOffsetByMediaID
        self.linkedMediaItems = linkedMediaItems
        _selectedMediaID = selectedMediaID
        self.configuration = configuration
        self.featuredMediaPhotoID = featuredMediaPhotoID
        self.onToggleFeatured = onToggleFeatured
        self.sightings = sightings
        self.marineLifeCatalog = marineLifeCatalog
        self.ownerProfileID = ownerProfileID
        self.onOpenDive = onOpenDive
    }

    private var selectedMedia: DiveMediaPhoto? {
        DiveActivityMediaPresentation.selectedMedia(
            selectedID: selectedMediaID,
            in: mediaItems
        )
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

    private var isSelectedMediaFeatured: Bool {
        guard let selectedMediaID, let featuredMediaPhotoID else { return false }
        return selectedMediaID == featuredMediaPhotoID
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

    var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size
            let dismissProgress = LinkedMediaFullscreenPresentation.dismissProgress(
                verticalTranslation: verticalDismissTranslation,
                containerHeight: containerSize.height
            )
            let dismissScale = LinkedMediaFullscreenPresentation.dismissScale(
                progress: dismissProgress
            )
            let backgroundOpacity = LinkedMediaFullscreenPresentation.dismissBackgroundOpacity(
                progress: dismissProgress
            )
            let chromeOpacity = 1 - Double(dismissProgress) * 0.35
            let overlaySize = containerSize
            let topChromeRowOffset = LinkedMediaFullscreenPresentation.topChromeRowOffset(
                safeAreaTop: geometry.safeAreaInsets.top,
                containerSize: containerSize
            )

            ZStack {
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()

                mediaPager(size: containerSize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .offset(y: verticalDismissTranslation)
                    .scaleEffect(dismissScale)
                    .gesture(interactionGesture(containerSize: containerSize))
                    .allowsHitTesting(!showsMarineLifeOverlay)

                if showsMarineLifeOverlay, !selectedMediaTaggedSpecies.isEmpty {
                    TripDetailMediaMarineLifeOverlay(
                        taggedSpecies: selectedMediaTaggedSpecies,
                        previewSize: overlaySize,
                        cornerRadius: 0,
                        ownerProfileID: ownerProfileID,
                        selectedSpeciesUUID: $selectedTaggedSpeciesUUID,
                        onOpenDive: onOpenDive,
                        onClose: closeMarineLifeOverlay
                    )
                    .transition(.opacity)
                }

                if !showsMarineLifeOverlay {
                    TripDetailMediaGalleryOverlayControls(
                        openOnDiveTitle: configuration.openOnDiveTitle,
                        positionLabel: TripDetailMediaGalleryPresentation.mediaPositionLabel(
                            selectedID: selectedMediaID,
                            in: mediaItems
                        ),
                        isFeatured: isSelectedMediaFeatured,
                        showsMarineLifeTagButton: configuration.showsMarineLifeTagButton,
                        openOnDivePlacement: configuration.openOnDivePlacement,
                        showsMarineLifeTagIndicator: showsMarineLifeTagIndicator,
                        onOpenOnDive: openSelectedMediaInDive,
                        onToggleFeatured: onToggleFeatured,
                        onToggleMarineLife: toggleMarineLifeOverlay,
                        featureToggleAccessibilityIdentifier: configuration.featureToggleAccessibilityIdentifier,
                        openOnDiveAccessibilityIdentifier: configuration.openOnDiveAccessibilityIdentifier,
                        marineLifeAccessibilityIdentifier: configuration.marineLifeAccessibilityIdentifier
                    )
                    .padding(.top, topChromeRowOffset)
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
                    .opacity(chromeOpacity)
                    .allowsHitTesting(chromeOpacity > 0.2)

                    closeButton(topRowOffset: topChromeRowOffset)
                        .opacity(chromeOpacity)
                        .allowsHitTesting(chromeOpacity > 0.2)
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showsMarineLifeOverlay)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(fullscreenAccessibilityLabel)
            .accessibilityHint(
                LinkedMediaFullscreenPresentation.browseAccessibilityHint(
                    itemCount: mediaItems.count
                )
            )
            .accessibilityAction(named: "Close") {
                dismissMedia(style: .closeButton)
            }
            .accessibilityAction(named: "Next") {
                advanceMedia(offset: 1, containerWidth: containerSize.width)
            }
            .accessibilityAction(named: "Previous") {
                advanceMedia(offset: -1, containerWidth: containerSize.width)
            }
            .onAppear {
                containerHeight = containerSize.height
            }
            .onChange(of: containerSize.height) { _, newHeight in
                containerHeight = newHeight
            }
            .onChange(of: selectedMediaID) { _, _ in
                closeMarineLifeOverlay()
            }
        }
        .ignoresSafeArea()
        .fullScreenCover(item: $linkedDivePresentation) { presentation in
            LinkedMediaFullscreenLinkedDiveCover(
                diveID: presentation.diveID,
                mediaID: presentation.mediaID
            )
        }
        .diveActivityLandscapeOrientation()
        .accessibilityIdentifier(configuration.rootAccessibilityIdentifier)
    }

    private func closeButton(topRowOffset: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button(action: { dismissMedia(style: .closeButton) }) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle()
                                .fill(.black.opacity(0.48))
                                .background {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                }
                                .clipShape(Circle())
                        }
                        .padding(AppTheme.Spacing.sm)
                        .frame(minWidth: 48, minHeight: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                .accessibilityIdentifier(configuration.closeAccessibilityIdentifier)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.top, topRowOffset)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func mediaPager(size: CGSize) -> some View {
        let progress = LinkedMediaFullscreenPresentation.interactiveBrowseProgress(
            horizontalTranslation: horizontalDragTranslation,
            containerWidth: size.width
        )
        let browseStep = LinkedMediaFullscreenPresentation.interactiveBrowseStep(
            forHorizontalTranslation: horizontalDragTranslation
        )

        ZStack {
            if let previousMedia = adjacentMedia(forBrowseStep: -1) {
                mountedMediaLayer(
                    for: previousMedia,
                    containerSize: size,
                    role: .previous,
                    progress: progress,
                    browseStep: browseStep
                )
            }

            if let nextMedia = adjacentMedia(forBrowseStep: 1) {
                mountedMediaLayer(
                    for: nextMedia,
                    containerSize: size,
                    role: .next,
                    progress: progress,
                    browseStep: browseStep
                )
            }

            if let selectedMedia {
                mountedMediaLayer(
                    for: selectedMedia,
                    containerSize: size,
                    role: .selected,
                    progress: progress,
                    browseStep: browseStep
                )
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func mountedMediaLayer(
        for media: DiveMediaPhoto,
        containerSize: CGSize,
        role: PreloadedMediaRole,
        progress: CGFloat,
        browseStep: Int?
    ) -> some View {
        let isInteractiveBrowse = horizontalDragTranslation != 0
        let showsAdjacentDuringBrowse = isInteractiveBrowse
            && ((role == .next && browseStep == 1) || (role == .previous && browseStep == -1))

        DiveActivityMediaItemView(
            media: media,
            timeZoneOffsetSeconds: timeZoneOffsetByMediaID[media.id] ?? nil,
            showsCaptureDateOverlay: false,
            isVideoPlaybackActive: isVideoPlaybackActive(for: media),
            loopsVideoPlayback: true
        )
        .frame(width: containerSize.width, height: containerSize.height)
        .id(media.id)
        .offset(
            x: mountedMediaOffsetX(
                role: role,
                containerWidth: containerSize.width,
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
        .allowsHitTesting(false)
        .zIndex(role == .selected ? 1 : 0)
    }

    private func isVideoPlaybackActive(for media: DiveMediaPhoto) -> Bool {
        media.resolvedMediaKind == .video
            && media.id == selectedMediaID
            && horizontalDragTranslation == 0
            && verticalDismissTranslation == 0
            && !showsMarineLifeOverlay
            && DiveBuddyDetailPresentation.shouldAutoPlaySelectedVideo(for: media)
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
                return LinkedMediaFullscreenPresentation.interactiveCurrentOpacity(progress: progress)
            }
            return 1
        case .previous, .next:
            if showsAdjacentDuringBrowse {
                return LinkedMediaFullscreenPresentation.interactiveAdjacentOpacity(progress: progress)
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
                return LinkedMediaFullscreenPresentation.interactiveCurrentScale(progress: progress)
            }
            return 1
        case .previous, .next:
            if showsAdjacentDuringBrowse {
                return LinkedMediaFullscreenPresentation.interactiveAdjacentScale(progress: progress)
            }
            return 1
        }
    }

    private func mountedMediaOffsetX(
        role: PreloadedMediaRole,
        containerWidth: CGFloat,
        showsAdjacentDuringBrowse: Bool
    ) -> CGFloat {
        switch role {
        case .selected:
            return horizontalDragTranslation
        case .previous, .next:
            guard showsAdjacentDuringBrowse else { return 0 }
            return LinkedMediaFullscreenPresentation.adjacentItemOffsetX(
                horizontalTranslation: horizontalDragTranslation,
                containerWidth: containerWidth
            )
        }
    }

    private func interactionGesture(containerSize: CGSize) -> some Gesture {
        DragGesture(
            minimumDistance: LinkedMediaFullscreenPresentation.swipeMinimumDistance,
            coordinateSpace: .local
        )
        .onChanged { value in
            if lockedDragAxis == nil {
                lockedDragAxis = LinkedMediaFullscreenPresentation.lockedDragAxis(
                    translation: value.translation
                )
            }

            switch lockedDragAxis {
            case .horizontal:
                horizontalDragTranslation = LinkedMediaFullscreenPresentation.rubberBandedBrowseTranslation(
                    value.translation.width,
                    canBrowseForward: canBrowseForward,
                    canBrowseBackward: canBrowseBackward
                )
            case .vertical:
                verticalDismissTranslation = value.translation.height
            case nil:
                break
            }
        }
        .onEnded { value in
            defer { lockedDragAxis = nil }

            switch lockedDragAxis {
            case .horizontal:
                handleHorizontalDragEnded(value: value, containerWidth: containerSize.width)
            case .vertical:
                handleVerticalDragEnded(value: value, containerHeight: containerSize.height)
            case nil:
                break
            }
        }
    }

    private func handleHorizontalDragEnded(value: DragGesture.Value, containerWidth: CGFloat) {
        let translation = LinkedMediaFullscreenPresentation.rubberBandedBrowseTranslation(
            value.translation.width,
            canBrowseForward: canBrowseForward,
            canBrowseBackward: canBrowseBackward
        )

        if let step = LinkedMediaFullscreenPresentation.browseOffset(
            forHorizontalTranslation: translation
        ), adjacentMedia(forBrowseStep: step) != nil {
            commitBrowse(step: step, containerWidth: containerWidth)
        } else {
            resetHorizontalDrag()
        }
    }

    private func handleVerticalDragEnded(value: DragGesture.Value, containerHeight: CGFloat) {
        if LinkedMediaFullscreenPresentation.shouldDismiss(
            verticalTranslation: value.translation.height,
            predictedEndTranslation: value.predictedEndTranslation.height,
            containerHeight: containerHeight
        ) {
            dismissMedia(style: .interactiveGesture)
        } else {
            resetVerticalDismissDrag()
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

    private func resetHorizontalDrag() {
        withAnimation(browseAnimation) {
            horizontalDragTranslation = 0
        }
    }

    private func resetVerticalDismissDrag() {
        withAnimation(gestureDismissAnimation) {
            verticalDismissTranslation = 0
        }
    }

    private func commitBrowse(step: Int, containerWidth: CGFloat) {
        guard let nextID = DiveActivityMediaPresentation.adjacentPhotoID(
            selectedID: selectedMediaID,
            in: mediaItems,
            offset: step
        ) else {
            resetHorizontalDrag()
            return
        }

        withAnimation(browseAnimation) {
            horizontalDragTranslation = LinkedMediaFullscreenPresentation.interactiveCommitTranslation(
                step: step,
                containerWidth: containerWidth
            )
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + LinkedMediaFullscreenPresentation.browseAnimationDuration
        ) {
            selectedMediaID = nextID
            horizontalDragTranslation = 0
        }
    }

    private func advanceMedia(offset: Int, containerWidth: CGFloat) {
        guard adjacentMedia(forBrowseStep: offset) != nil else { return }
        commitBrowse(step: offset, containerWidth: containerWidth)
    }

    private enum DismissStyle {
        case closeButton
        case interactiveGesture
    }

    private func dismissMedia(style: DismissStyle) {
        switch style {
        case .closeButton:
            dismiss()
        case .interactiveGesture:
            withAnimation(gestureDismissAnimation) {
                let direction: CGFloat = verticalDismissTranslation >= 0 ? 1 : -1
                verticalDismissTranslation = direction * max(containerHeight, 1)
            }

            DispatchQueue.main.asyncAfter(
                deadline: .now() + LinkedMediaFullscreenPresentation.gestureDismissAnimationDuration
            ) {
                dismiss()
            }
        }
    }

    private func toggleMarineLifeOverlay() {
        guard configuration.showsMarineLifeTagButton, showsMarineLifeTagIndicator else { return }
        selectedTaggedSpeciesUUID = selectedMediaTaggedSpecies.first?.uuid
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            showsMarineLifeOverlay = true
        }
    }

    private func closeMarineLifeOverlay() {
        guard showsMarineLifeOverlay else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            showsMarineLifeOverlay = false
        }
    }

    private var browseAnimation: Animation {
        .spring(
            response: LinkedMediaFullscreenPresentation.browseAnimationDuration,
            dampingFraction: LinkedMediaFullscreenPresentation.browseAnimationDamping
        )
    }

    private var gestureDismissAnimation: Animation {
        .spring(
            response: LinkedMediaFullscreenPresentation.gestureDismissSpringResponse,
            dampingFraction: LinkedMediaFullscreenPresentation.gestureDismissSpringDamping
        )
    }

    private var fullscreenAccessibilityLabel: String {
        let kind = selectedMedia?.resolvedMediaKind == .video ? "Video" : "Photo"
        let position = TripDetailMediaGalleryPresentation.mediaPositionLabel(
            selectedID: selectedMediaID,
            in: mediaItems
        )
        if let position {
            return "\(configuration.accessibilityContextLabel) \(kind.lowercased()), \(position)"
        }
        return "\(configuration.accessibilityContextLabel) \(kind.lowercased())"
    }

    private func openSelectedMediaInDive() {
        guard let mediaID = selectedMediaID,
              let diveID = TripDetailMediaPresentation.diveActivityID(
                for: mediaID,
                in: linkedMediaItems
              )
        else { return }
        linkedDivePresentation = LinkedDivePresentation(diveID: diveID, mediaID: mediaID)
    }
}

private struct LinkedMediaFullscreenLinkedDiveCover: View {
    let diveID: UUID
    let mediaID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var resolvedActivity: DiveActivity? {
        let targetID = diveID
        var descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate { activity in
                activity.id == targetID
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    var body: some View {
        Group {
            if let activity = resolvedActivity {
                ViewSingleActivity(activity: activity, initialMediaFocusID: mediaID)
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: AppTheme.Spacing.md) {
                        Text("Dive unavailable")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("This dive is no longer available.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                        Button("Close") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(AppTheme.Spacing.lg)
                }
            }
        }
    }
}

typealias DiveBuddyTaggedMediaFullscreenView = LinkedMediaFullscreenView
