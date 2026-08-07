import SwiftData
import SwiftUI

/// Full-screen friend activity media — **playback stack duplicated from**
/// **`LinkedMediaFullscreenView`** (custom pager, vertical dismiss, center play/pause,
/// aspect-fill stills, landscape unlock). Tag chrome stays view-only (no star / plus / AI).
struct FriendSharedMediaFullscreenView: View {
    private enum PreloadedMediaRole {
        case previous
        case selected
        case next
    }

    private enum DismissStyle {
        case closeButton
        case interactiveGesture
    }

    let items: [FriendSharedMediaPresentation.DisplayItem]
    var diveByMediaID: [String: GoDiveSharedDiveProjectionMapping.FriendVisibleDive] = [:]
    @Binding var selectedMediaID: String?
    /// Opens the owning shared activity (profile grid). Nil still shows the activity chip.
    var onOpenActivity: ((GoDiveSharedDiveProjectionMapping.FriendVisibleDive) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var horizontalDragTranslation: CGFloat = 0
    @State private var verticalDismissTranslation: CGFloat = 0
    @State private var lockedDragAxis: LinkedMediaFullscreenPresentation.DragAxis?
    @State private var containerHeight: CGFloat = 800
    @State private var showsTagOverviewSheet = false
    @State private var tagOverviewMode: DiveActivityMediaLargeDetentMode = .marineLife
    @State private var selectedTaggedSpeciesUUID: String?
    @State private var tagOverviewGrabberTranslation: CGFloat = 0
    @State private var isPlaybackPausedByUser = false
    @State private var showsPlaybackChrome = true
    @State private var commonNameByUUID: [String: String] = [:]

    private var isTagSheetPresented: Bool {
        showsTagOverviewSheet
    }

    private var selectedItem: FriendSharedMediaPresentation.DisplayItem? {
        FriendSharedMediaFullscreenPresentation.selectedItem(
            selectedID: selectedMediaID,
            in: items
        )
    }

    private var selectedDive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive? {
        guard let mediaID = selectedItem?.mediaID else { return nil }
        return diveByMediaID[mediaID]
    }

    private var taggedSpecies: [MarineLife] {
        guard let dive = selectedDive else { return [] }
        return FriendSharedActivityDetailPresentation.displayMarineLife(
            from: dive,
            commonNameByUUID: commonNameByUUID
        )
    }

    private var taggedBuddies: [DiveBuddy] {
        guard let dive = selectedDive else { return [] }
        return FriendSharedActivityDetailPresentation.displayBuddies(
            from: dive,
            mediaID: selectedItem?.mediaID
        )
    }

    private var canBrowseForward: Bool {
        FriendSharedMediaFullscreenPresentation.adjacentMediaID(
            selectedID: selectedMediaID,
            in: items,
            offset: 1
        ) != nil
    }

    private var canBrowseBackward: Bool {
        FriendSharedMediaFullscreenPresentation.adjacentMediaID(
            selectedID: selectedMediaID,
            in: items,
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
            let isSelectedVideo = selectedItem?.kind == .video
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
                    bottomChrome
                        .padding(.top, topChromeRowOffset)
                        .padding(.bottom, geometry.safeAreaInsets.bottom)
                        .opacity(chromeOpacity)
                        .allowsHitTesting(chromeOpacity > 0.2)
                }

                closeAndPositionChrome(
                    topRowOffset: topChromeRowOffset,
                    positionLabel: FriendSharedMediaFullscreenPresentation.mediaPositionLabel(
                        selectedID: selectedMediaID,
                        in: items
                    ),
                    showsCloseButton: !showsTagOverviewSheet
                )
                .opacity(chromeOpacity)
                .allowsHitTesting(chromeOpacity > 0.2 && !isTagSheetPresented)

                if showsTagOverviewSheet {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: dismissTagOverview)
                        .accessibilityLabel("Dismiss media tags overview")
                        .accessibilityAddTraits(.isButton)

                    tagOverviewEmbeddedPanel(
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
                        action: togglePlaybackPausedByUser,
                        accessibilityIdentifier:
                            FriendSharedMediaFullscreenPresentation.playbackToggleAccessibilityIdentifier
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
                LinkedMediaFullscreenPresentation.browseAccessibilityHint(itemCount: items.count)
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
                if selectedMediaID == nil {
                    selectedMediaID = items.first?.mediaID
                }
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
        }
        .ignoresSafeArea()
        .diveActivityLandscapeOrientation()
        .accessibilityIdentifier(FriendSharedMediaFullscreenPresentation.rootAccessibilityIdentifier)
        .task {
            commonNameByUUID = MarineLifeSpeciesResolver.commonNameByUUID(modelContext: modelContext)
        }
        .task(id: prefetchToken) {
            await prefetchAdjacentContent()
        }
        .onChange(of: selectedMediaID) { _, newValue in
            selectedTaggedSpeciesUUID = nil
            tagOverviewMode = .marineLife
            Task {
                await prefetchContent(around: newValue)
            }
        }
        .onChange(of: taggedSpecies.map(\.uuid)) { _, uuids in
            if let selectedTaggedSpeciesUUID, uuids.contains(selectedTaggedSpeciesUUID) {
                return
            }
            selectedTaggedSpeciesUUID = uuids.first
        }
    }

    private var prefetchToken: String {
        items.map(\.mediaID).joined(separator: "-")
    }

    private var fullscreenAccessibilityLabel: String {
        let kind = selectedItem?.kind == .video ? "Video" : "Photo"
        if let position = FriendSharedMediaFullscreenPresentation.mediaPositionLabel(
            selectedID: selectedMediaID,
            in: items
        ) {
            return "\(FriendSharedMediaFullscreenPresentation.accessibilityContextLabel) \(kind.lowercased()), \(position)"
        }
        return "\(FriendSharedMediaFullscreenPresentation.accessibilityContextLabel) \(kind.lowercased())"
    }

    @ViewBuilder
    private var bottomChrome: some View {
        if let dive = selectedDive {
            TripDetailMediaGalleryOverlayControls(
                bottomLeadingChrome: .diveLink(
                    siteDisplayName: FriendSharedMediaFullscreenPresentation.siteDisplayName(for: dive),
                    diveNumberLabel: FriendSharedMediaFullscreenPresentation.diveNumberLabel(for: dive),
                    linkedTripTitle: nil,
                    onOpenOnDive: { openActivity(dive) }
                ),
                isFeatured: false,
                showsMediaTagButtons: true,
                hasBuddyTags: !taggedBuddies.isEmpty,
                hasMarineLifeTags: !taggedSpecies.isEmpty,
                onToggleFeatured: nil,
                onToggleMarineLife: { presentTagOverview(mode: .marineLife) },
                onToggleBuddy: { presentTagOverview(mode: .buddies) },
                openOnDiveAccessibilityIdentifier:
                    FriendSharedMediaFullscreenPresentation.openActivityAccessibilityIdentifier,
                marineLifeAccessibilityIdentifier:
                    FriendSharedMediaFullscreenPresentation.marineLifeAccessibilityIdentifier,
                buddyAccessibilityIdentifier:
                    FriendSharedMediaFullscreenPresentation.buddyAccessibilityIdentifier
            )
        }
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
                    .accessibilityIdentifier(
                        FriendSharedMediaFullscreenPresentation.closeAccessibilityIdentifier
                    )
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
            if let previousItem = adjacentItem(forBrowseStep: -1) {
                mountedMediaLayer(
                    for: previousItem,
                    containerSize: size,
                    role: .previous,
                    progress: progress,
                    browseStep: browseStep
                )
            }

            if let nextItem = adjacentItem(forBrowseStep: 1) {
                mountedMediaLayer(
                    for: nextItem,
                    containerSize: size,
                    role: .next,
                    progress: progress,
                    browseStep: browseStep
                )
            }

            if let selectedItem {
                mountedMediaLayer(
                    for: selectedItem,
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
        for item: FriendSharedMediaPresentation.DisplayItem,
        containerSize: CGSize,
        role: PreloadedMediaRole,
        progress: CGFloat,
        browseStep: Int?
    ) -> some View {
        let isInteractiveBrowse = horizontalDragTranslation != 0
        let showsAdjacentDuringBrowse = isInteractiveBrowse
            && ((role == .next && browseStep == 1) || (role == .previous && browseStep == -1))

        Group {
            if item.kind == .video {
                FriendSharedRemoteVideoPlayerView(
                    item: item,
                    isPlaybackActive: isVideoPlaybackActive(for: item),
                    isPausedByUserHold: isPlaybackPausedByUser && item.mediaID == selectedMediaID,
                    loopsPlayback: true,
                    usesFullscreenMountSettleDelay: true
                )
            } else {
                FriendSharedMediaImageView(
                    item: item,
                    fidelity: role == .selected ? .progressive : .thumbnailOnly,
                    showsVideoBadge: false
                )
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .clipped()
        .id(item.mediaID)
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

    private func isVideoPlaybackActive(for item: FriendSharedMediaPresentation.DisplayItem) -> Bool {
        item.kind == .video
            && item.mediaID == selectedMediaID
            && horizontalDragTranslation == 0
            && verticalDismissTranslation == 0
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
        ), adjacentItem(forBrowseStep: step) != nil {
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

    private func adjacentItem(forBrowseStep step: Int?) -> FriendSharedMediaPresentation.DisplayItem? {
        guard let step,
              let adjacentID = FriendSharedMediaFullscreenPresentation.adjacentMediaID(
                selectedID: selectedMediaID,
                in: items,
                offset: step
              )
        else { return nil }
        return items.first(where: { $0.mediaID == adjacentID })
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
        guard let nextID = FriendSharedMediaFullscreenPresentation.adjacentMediaID(
            selectedID: selectedMediaID,
            in: items,
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
        guard adjacentItem(forBrowseStep: offset) != nil else { return }
        commitBrowse(step: offset, containerWidth: containerWidth)
    }

    private func dismissMedia(style: DismissStyle) {
        switch style {
        case .closeButton:
            selectedMediaID = nil
            dismiss()
        case .interactiveGesture:
            withAnimation(gestureDismissAnimation) {
                let direction: CGFloat = verticalDismissTranslation >= 0 ? 1 : -1
                verticalDismissTranslation = direction * max(containerHeight, 1)
            }

            DispatchQueue.main.asyncAfter(
                deadline: .now() + LinkedMediaFullscreenPresentation.gestureDismissAnimationDuration
            ) {
                selectedMediaID = nil
                dismiss()
            }
        }
    }

    private func togglePlaybackChrome() {
        guard !isTagSheetPresented else { return }
        showsPlaybackChrome.toggle()
    }

    private func togglePlaybackPausedByUser() {
        guard selectedItem?.kind == .video else { return }
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
        guard selectedItem != nil else { return }
        tagOverviewGrabberTranslation = 0
        tagOverviewMode = mode
        if mode == .marineLife {
            selectedTaggedSpeciesUUID = taggedSpecies.first?.uuid
        }
        withAnimation(.diveOverviewPanelDetent) {
            showsTagOverviewSheet = true
        }
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

            DiveActivityMediaLargeDetentOverviewContent(
                mode: $tagOverviewMode,
                media: nil,
                taggedSpecies: taggedSpecies,
                taggedBuddies: taggedBuddies,
                onTagMarineLife: nil,
                onTagBuddies: nil,
                onIdentifyFish: nil,
                selectedTaggedSpeciesUUID: $selectedTaggedSpeciesUUID,
                overlaysChrome: true,
                onCollapseToMedium: dismissTagOverview
            )
            .allowsHitTesting(!isDragging)
        }
        .frame(height: displayedHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .clipped()
        .animation(isDragging ? nil : .diveOverviewPanelDetent, value: displayedHeight)
        .diveActivityMediaLargeDetentOverviewEmbeddedChrome()
        .accessibilityIdentifier(
            FriendSharedMediaFullscreenPresentation.tagOverviewAccessibilityIdentifier
        )
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

    private func openActivity(_ dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive) {
        dismissMedia(style: .closeButton)
        onOpenActivity?(dive)
    }

    private func prefetchAdjacentContent() async {
        let contentURLs = FriendSharedMediaPresentation.detailContentPrefetchURLs(
            items: items,
            selectedMediaID: selectedMediaID
        )
        await prefetchContentURLs(contentURLs)
    }

    private func prefetchContent(around selectedID: String?) async {
        let contentURLs = FriendSharedMediaPresentation.detailContentPrefetchURLs(
            items: items,
            selectedMediaID: selectedID
        )
        await prefetchContentURLs(contentURLs)
    }

    private func prefetchContentURLs(_ urls: [String]) async {
        let snapshot = AppNetworkConnectivitySnapshot.shared
        let allowsContent = AppNetworkConnectivityPresentation.allowsFriendSharedMediaContentDownload(
            isConnected: snapshot.allowsCloudMediaFetch,
            usesWiFi: snapshot.usesWiFiInterface,
            wifiOnly: AppUserSettings.downloadFriendMediaOnWiFiOnly(),
            allowsConstrainedNetworkAccess: URLSession.shared.configuration.allowsConstrainedNetworkAccess
        )
        guard allowsContent else { return }
        await GoDiveSharedMediaCache.shared.prefetch(
            remoteURLStrings: urls,
            tier: .content,
            allowsNetworkFetch: true
        )
    }
}
