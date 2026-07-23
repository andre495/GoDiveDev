import SwiftData
import SwiftUI

/// Full-screen linked media — horizontal browse, vertical dismiss, optional marine-life overlay.
struct LinkedMediaFullscreenView: View {
    struct Configuration: Sendable {
        enum BottomLeadingChrome: Sendable {
            case diveLink
            case captureTimestamp
        }

        let rootAccessibilityIdentifier: String
        let closeAccessibilityIdentifier: String
        let openOnDiveAccessibilityIdentifier: String
        let featureToggleAccessibilityIdentifier: String
        let marineLifeAccessibilityIdentifier: String
        let accessibilityContextLabel: String
        let showsMarineLifeTagButton: Bool
        let bottomLeadingChrome: BottomLeadingChrome
        var buddyAccessibilityIdentifier: String {
            "\(rootAccessibilityIdentifier).BuddyTag"
        }

        /// Prefer **`showsMediaTagButtons`** — kept as `showsMarineLifeTagButton` for call-site compatibility.
        var showsMediaTagButtons: Bool { showsMarineLifeTagButton }

        static let buddy = Configuration(
            rootAccessibilityIdentifier: "DiveBuddyDetails.TaggedMedia.Fullscreen",
            closeAccessibilityIdentifier: "DiveBuddyDetails.TaggedMedia.Fullscreen.Close",
            openOnDiveAccessibilityIdentifier: "DiveBuddyDetails.TaggedMedia.OpenOnDive",
            featureToggleAccessibilityIdentifier: "DiveBuddyDetails.TaggedMedia.FeatureToggle",
            marineLifeAccessibilityIdentifier: "DiveBuddyDetails.TaggedMedia.MarineLifeTag",
            accessibilityContextLabel: "Buddy tagged",
            showsMarineLifeTagButton: true,
            bottomLeadingChrome: .diveLink
        )

        static let trip = Configuration(
            rootAccessibilityIdentifier: "TripDetail.Media.Fullscreen",
            closeAccessibilityIdentifier: "TripDetail.Media.Fullscreen.Close",
            openOnDiveAccessibilityIdentifier: "TripDetail.Media.OpenOnDive",
            featureToggleAccessibilityIdentifier: "TripDetail.Media.FeatureToggle",
            marineLifeAccessibilityIdentifier: "TripDetail.Media.MarineLifeTag",
            accessibilityContextLabel: "Trip media",
            showsMarineLifeTagButton: true,
            bottomLeadingChrome: .diveLink
        )

        static let diveSite = Configuration(
            rootAccessibilityIdentifier: "Explore.DiveSiteDetail.TaggedMedia.Fullscreen",
            closeAccessibilityIdentifier: "Explore.DiveSiteDetail.TaggedMedia.Fullscreen.Close",
            openOnDiveAccessibilityIdentifier: "Explore.DiveSiteDetail.TaggedMedia.OpenOnDive",
            featureToggleAccessibilityIdentifier: "Explore.DiveSiteDetail.TaggedMedia.FeatureToggle",
            marineLifeAccessibilityIdentifier: "Explore.DiveSiteDetail.TaggedMedia.MarineLifeTag",
            accessibilityContextLabel: "Dive site tagged",
            showsMarineLifeTagButton: true,
            bottomLeadingChrome: .diveLink
        )

        /// Landscape tank depth-chart marker — same fullscreen chrome as linked grids; capture time in the lower leading corner.
        static let diveDepthChart = Configuration(
            rootAccessibilityIdentifier: "DiveActivity.DepthChart.Media.Fullscreen",
            closeAccessibilityIdentifier: "DiveActivity.DepthChart.Media.Fullscreen.Close",
            openOnDiveAccessibilityIdentifier: "DiveActivity.DepthChart.Media.OpenOnDive",
            featureToggleAccessibilityIdentifier: "DiveActivity.DepthChart.Media.FeatureToggle",
            marineLifeAccessibilityIdentifier: "DiveActivity.DepthChart.Media.MarineLifeTag",
            accessibilityContextLabel: "Dive media",
            showsMarineLifeTagButton: true,
            bottomLeadingChrome: .captureTimestamp
        )
    }

    private enum PreloadedMediaRole {
        case previous
        case selected
        case next
    }

    let mediaItems: [DiveMediaPhoto]
    let timeZoneOffsetByMediaID: [UUID: Int?]
    let captureContextByMediaID: [UUID: DiveMediaCaptureContext]
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
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = true

    @State private var horizontalDragTranslation: CGFloat = 0
    @State private var verticalDismissTranslation: CGFloat = 0
    @State private var lockedDragAxis: LinkedMediaFullscreenPresentation.DragAxis?
    @State private var containerHeight: CGFloat = 800
    @State private var showsTagOverviewSheet = false
    @State private var tagOverviewMode: DiveActivityMediaLargeDetentMode = .marineLife
    @State private var selectedTaggedSpeciesUUID: String?
    @State private var linkedDivePresentation: LinkedDivePresentation?
    @State private var didApplyInitialTagOverview = false
    /// Interactive drag offset while the user pulls the tag-overview grabber down to dismiss.
    @State private var tagOverviewGrabberTranslation: CGFloat = 0
    /// Explicit center play/pause toggle (stays until play, media change, or browse).
    @State private var isPlaybackPausedByUser = false
    /// Top / bottom / center chrome — tap empty media area to hide / show (Photos-style).
    @State private var showsPlaybackChrome = true

    /// When set, presents the dive Media **large**-detent overview sheet on first appearance.
    var initialTagOverviewMode: DiveActivityMediaLargeDetentMode? = nil

    private var isTagSheetPresented: Bool {
        showsTagOverviewSheet
    }

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
        captureContextByMediaID: [UUID: DiveMediaCaptureContext] = [:],
        featuredMediaPhotoID: UUID? = nil,
        onToggleFeatured: (() -> Void)? = nil,
        sightings: [SightingInstance] = [],
        marineLifeCatalog: [MarineLife] = [],
        ownerProfileID: UUID? = nil,
        initialTagOverviewMode: DiveActivityMediaLargeDetentMode? = nil,
        onOpenDive: @escaping (UUID) -> Void = { _ in }
    ) {
        self.mediaItems = mediaItems
        self.timeZoneOffsetByMediaID = timeZoneOffsetByMediaID
        self.captureContextByMediaID = captureContextByMediaID
        self.linkedMediaItems = linkedMediaItems
        _selectedMediaID = selectedMediaID
        self.configuration = configuration
        self.featuredMediaPhotoID = featuredMediaPhotoID
        self.onToggleFeatured = onToggleFeatured
        self.sightings = sightings
        self.marineLifeCatalog = marineLifeCatalog
        self.ownerProfileID = ownerProfileID
        self.initialTagOverviewMode = initialTagOverviewMode
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

    private var selectedMediaTaggedBuddyModels: [DiveBuddy] {
        guard let selectedMediaID, let dive = selectedDiveForTagging else { return [] }
        return DiveMediaBuddyTagPresentation.resolvedTaggedBuddies(
            mediaPhotoID: selectedMediaID,
            tags: dive.mediaBuddyTags
        )
    }

    private var selectedDiveLinkSiteDisplayName: String {
        LinkedMediaFullscreenDiveLinkPresentation.siteDisplayName(for: selectedDiveForTagging)
    }

    private var selectedDiveLinkNumberLabel: String {
        LinkedMediaFullscreenDiveLinkPresentation.diveNumberLabel(
            for: selectedDiveForTagging,
            useChronologicalNumbers: automaticallyRenumberDives,
            chronologicalIndexByDiveID: selectedDiveChronologicalIndexByID
        )
    }

    private var selectedDiveLinkTripTitle: String? {
        LinkedMediaFullscreenDiveLinkPresentation.linkedTripTitle(for: selectedDiveForTagging)
    }

    private var selectedCaptureTimestampLabels: (primary: String, secondary: String?)? {
        guard let selectedMedia else { return nil }
        return LinkedMediaFullscreenPresentation.bottomLeadingCaptureTimestampLabels(
            media: selectedMedia,
            captureContext: captureContextByMediaID[selectedMedia.id],
            timeZoneOffsetSeconds: timeZoneOffsetByMediaID[selectedMedia.id] ?? nil,
            displayUnits: diveDisplayUnitSystem
        )
    }

    private var selectedDiveChronologicalIndexByID: [UUID: Int] {
        guard automaticallyRenumberDives, let ownerProfileID else { return [:] }
        guard let index = OwnerDiveIndexSessionCache.resolve(ownerProfileID: ownerProfileID) else {
            return [:]
        }
        return DiveActivityDiveNumbering.numberedDiveSequentialIndicesById(for: index.numberingRows)
    }

    private var selectedDiveForTagging: DiveActivity? {
        if let dive = selectedMedia?.dive {
            return dive
        }
        guard let diveActivityID = selectedMedia?.diveActivityID else { return nil }
        var descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate { $0.id == diveActivityID }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
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
            let chromeOpacity = LinkedMediaFullscreenPresentation.playbackChromeOpacity(
                dismissProgress: dismissProgress,
                showsPlaybackChrome: showsPlaybackChrome
            )
            let topChromeRowOffset = LinkedMediaFullscreenPresentation.topChromeRowOffset(
                safeAreaTop: geometry.safeAreaInsets.top,
                containerSize: containerSize
            )
            let isSelectedVideo = selectedMedia?.resolvedMediaKind == .video
            let showsCenterPlaybackControl = LinkedMediaFullscreenPresentation.showsCenterPlaybackControl(
                isVideo: isSelectedVideo,
                showsPlaybackChrome: showsPlaybackChrome
            )

            ZStack(alignment: .bottom) {
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()

                mediaPager(size: containerSize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .offset(y: verticalDismissTranslation)
                    .scaleEffect(dismissScale)
                    .gesture(interactionGesture(containerSize: containerSize))
                    .onTapGesture(perform: togglePlaybackChrome)
                    .allowsHitTesting(!isTagSheetPresented)

                if !showsTagOverviewSheet {
                    TripDetailMediaGalleryOverlayControls(
                        bottomLeadingChrome: configuration.bottomLeadingChrome == .captureTimestamp
                            ? .captureTimestamp(
                                primaryLine: selectedCaptureTimestampLabels?.primary
                                    ?? DiveActivityMediaPresentation.captureDateUnknownMessage,
                                secondaryLine: selectedCaptureTimestampLabels?.secondary
                            )
                            : .diveLink(
                                siteDisplayName: selectedDiveLinkSiteDisplayName,
                                diveNumberLabel: selectedDiveLinkNumberLabel,
                                linkedTripTitle: selectedDiveLinkTripTitle,
                                onOpenOnDive: openSelectedMediaInDive
                            ),
                        isFeatured: isSelectedMediaFeatured,
                        showsMediaTagButtons: configuration.showsMediaTagButtons,
                        hasBuddyTags: !selectedMediaTaggedBuddyModels.isEmpty,
                        hasMarineLifeTags: !selectedMediaTaggedSpecies.isEmpty,
                        onToggleFeatured: onToggleFeatured,
                        onToggleMarineLife: presentMarineLifeTagSheet,
                        onToggleBuddy: presentBuddyTagSheet,
                        featureToggleAccessibilityIdentifier: configuration.featureToggleAccessibilityIdentifier,
                        openOnDiveAccessibilityIdentifier: configuration.openOnDiveAccessibilityIdentifier,
                        marineLifeAccessibilityIdentifier: configuration.marineLifeAccessibilityIdentifier,
                        buddyAccessibilityIdentifier: configuration.buddyAccessibilityIdentifier,
                        captureTimestampAccessibilityIdentifier: "\(configuration.rootAccessibilityIdentifier).CaptureTimestamp"
                    )
                    .padding(.top, topChromeRowOffset)
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
                    .opacity(chromeOpacity)
                    .allowsHitTesting(chromeOpacity > 0.2)
                }

                closeAndPositionChrome(
                    topRowOffset: topChromeRowOffset,
                    positionLabel: TripDetailMediaGalleryPresentation.mediaPositionLabel(
                        selectedID: selectedMediaID,
                        in: mediaItems
                    ),
                    showsCloseButton: !showsTagOverviewSheet
                )
                .opacity(chromeOpacity)
                .allowsHitTesting(chromeOpacity > 0.2 && !isTagSheetPresented)

                if showsTagOverviewSheet, let media = selectedMedia {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: dismissTagOverview)
                        .accessibilityLabel("Dismiss media tags overview")
                        .accessibilityAddTraits(.isButton)

                    tagOverviewEmbeddedPanel(
                        media: media,
                        layoutContext: DiveActivityOverviewSheetLayoutContext(
                            layoutHeight: containerSize.height,
                            screenWidth: containerSize.width,
                            topSafeInset: geometry.safeAreaInsets.top,
                            bottomSafeInset: geometry.safeAreaInsets.bottom
                        )
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if showsCenterPlaybackControl, !isTagSheetPresented {
                    LinkedMediaFullscreenCenterPlaybackControl(
                        isPaused: isPlaybackPausedByUser,
                        action: togglePlaybackPausedByUser
                    )
                    .opacity(chromeOpacity)
                    .allowsHitTesting(chromeOpacity > 0.2)
                    .offset(y: verticalDismissTranslation)
                    .scaleEffect(dismissScale)
                }
            }
            .animation(.diveOverviewPanelDetent, value: showsTagOverviewSheet)
            .animation(.easeInOut(duration: 0.18), value: showsPlaybackChrome)
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
                isPlaybackPausedByUser = false
                showsTagOverviewSheet = false
            }
            .onChange(of: isTagSheetPresented) { _, isShowing in
                if isShowing {
                    showsPlaybackChrome = true
                }
            }
            .onAppear(perform: applyInitialTagOverviewIfNeeded)
        }
        .ignoresSafeArea()
        .fullScreenCover(item: $linkedDivePresentation) { presentation in
            LinkedMediaFullscreenLinkedDiveCover(diveID: presentation.diveID)
        }
        .diveActivityLandscapeOrientation()
        .accessibilityIdentifier(configuration.rootAccessibilityIdentifier)
    }

    private func closeAndPositionChrome(
        topRowOffset: CGFloat,
        positionLabel: String?,
        showsCloseButton: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                if showsCloseButton {
                    Button(action: { dismissMedia(style: .closeButton) }) {
                        Image(systemName: "xmark")
                            .appToolbarIconButtonLabel()
                    }
                    .appStandaloneIconButtonStyle()
                    .foregroundStyle(.white)
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier(configuration.closeAccessibilityIdentifier)
                }

                Spacer(minLength: 0)
                    .allowsHitTesting(false)

                if let positionLabel {
                    Text(positionLabel)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(height: LinkedMediaFullscreenPresentation.topChromeControlHeight)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.top, topRowOffset)

            Spacer(minLength: 0)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            loopsVideoPlayback: true,
            enablesHoldToPauseGesture: false,
            isPausedByUserHoldFromParent: isPlaybackPausedByUser && media.id == selectedMediaID
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

    private func applyInitialTagOverviewIfNeeded() {
        guard !didApplyInitialTagOverview,
              let initialTagOverviewMode,
              selectedMedia != nil
        else { return }
        didApplyInitialTagOverview = true
        // Defer so the fullscreen cover finishes presenting before the large overview sheet.
        Task { @MainActor in
            presentTagOverview(mode: initialTagOverviewMode)
        }
    }

    private func togglePlaybackChrome() {
        guard !isTagSheetPresented else { return }
        showsPlaybackChrome.toggle()
    }

    private func togglePlaybackPausedByUser() {
        guard selectedMedia?.resolvedMediaKind == .video else { return }
        isPlaybackPausedByUser.toggle()
        if !showsPlaybackChrome {
            showsPlaybackChrome = true
        }
    }

    private func dismissTagOverview() {
        withAnimation(.diveOverviewPanelDetent) {
            showsTagOverviewSheet = false
            tagOverviewGrabberTranslation = 0
        }
    }

    private func presentTagOverview(mode: DiveActivityMediaLargeDetentMode) {
        guard configuration.showsMediaTagButtons, selectedMedia != nil else { return }
        tagOverviewGrabberTranslation = 0
        tagOverviewMode = mode
        if mode == .marineLife {
            selectedTaggedSpeciesUUID = selectedMediaTaggedSpecies.first?.uuid
        }
        withAnimation(.diveOverviewPanelDetent) {
            showsTagOverviewSheet = true
        }
    }

    private func presentMarineLifeTagSheet() {
        guard configuration.showsMediaTagButtons, selectedMedia != nil else { return }
        presentTagOverview(mode: .marineLife)
    }

    private func presentBuddyTagSheet() {
        guard configuration.showsMediaTagButtons, selectedMedia != nil else { return }
        presentTagOverview(mode: .buddies)
    }

    private var tagOverviewGrabberDragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    tagOverviewGrabberTranslation = max(0, value.translation.height)
                }
            }
            .onEnded { value in
                if LinkedMediaFullscreenPresentation.shouldDismissTagOverview(
                    verticalTranslation: value.translation.height,
                    predictedEndTranslation: value.predictedEndTranslation.height
                ) {
                    dismissTagOverview()
                } else {
                    withAnimation(.diveOverviewPanelDetent) {
                        tagOverviewGrabberTranslation = 0
                    }
                }
            }
    }

    @ViewBuilder
    private func tagOverviewEmbeddedPanel(
        media: DiveMediaPhoto,
        layoutContext: DiveActivityOverviewSheetLayoutContext
    ) -> some View {
        let panelHeight = LinkedMediaFullscreenPresentation.tagOverviewPanelHeight(
            in: layoutContext
        )
        let isDragging = tagOverviewGrabberTranslation != 0
        let displayedHeight = max(0, panelHeight - tagOverviewGrabberTranslation)

        VStack(spacing: 0) {
            Capsule()
                .fill(AppTheme.Colors.tabUnselected.opacity(0.55))
                .frame(width: 36, height: 5)
                .padding(.top, AppTheme.Spacing.sm)
                .padding(.bottom, AppTheme.Spacing.sm)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 28)
                .contentShape(Rectangle())
                .highPriorityGesture(tagOverviewGrabberDragGesture)
                .accessibilityLabel("Dismiss media tags overview")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Swipe down to close")
                .accessibilityAction(named: "Close") {
                    dismissTagOverview()
                }

            DiveActivityMediaLargeDetentOverviewSheet(
                mode: $tagOverviewMode,
                media: media,
                dive: selectedDiveForTagging,
                taggedSpecies: selectedMediaTaggedSpecies,
                taggedBuddies: selectedMediaTaggedBuddyModels,
                selectedTaggedSpeciesUUID: $selectedTaggedSpeciesUUID,
                onOpenDive: onOpenDive
            )
            .scrollDisabled(isDragging)
        }
        .frame(height: displayedHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .clipped()
        .animation(isDragging ? nil : .diveOverviewPanelDetent, value: displayedHeight)
        .diveActivityMediaLargeDetentOverviewEmbeddedChrome()
        .accessibilityIdentifier("LinkedMedia.TagOverviewEmbeddedPanel")
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

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var resolvedActivity: DiveActivity?
    @State private var hasResolvedActivity = false

    var body: some View {
        Group {
            if let activity = resolvedActivity {
                // **View** from linked media opens the dive on the default **map** tab (not Media).
                ViewSingleActivity(activity: activity)
            } else if !hasResolvedActivity {
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
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
        .task(id: diveID) {
            hasResolvedActivity = false
            resolvedActivity = nil
            await Task.yield()
            let targetID = diveID
            var descriptor = FetchDescriptor<DiveActivity>(
                predicate: #Predicate { activity in
                    activity.id == targetID
                }
            )
            descriptor.fetchLimit = 1
            let activity = (try? modelContext.fetch(descriptor))?.first
            guard !Task.isCancelled else { return }
            resolvedActivity = activity
            hasResolvedActivity = true
        }
    }
}

typealias DiveBuddyTaggedMediaFullscreenView = LinkedMediaFullscreenView
