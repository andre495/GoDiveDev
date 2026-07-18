import SwiftData
import SwiftUI
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(Photos)
import Photos
#endif

// MARK: - Media carousel

enum HomeMediaCarouselLayout {
    /// Hero height = width × ratio + top safe inset + extension into the stats sheet overlap zone.
    static let heroHeightToWidthRatio: CGFloat = HomeOverviewLayout.heroHeightToWidthRatio

    /// Bottom inset for slide chrome — sits in the hero/panel overlap band (UI only; does not move the sheet seam).
    static var slideChromeBottomInset: CGFloat {
        HomeLifetimeStatsLayout.panelOverlap - AppTheme.Spacing.md
    }

    /// Dive-site capsule + fish / buddy icon chips share this height.
    static var slideChromeControlHeight: CGFloat {
        HomeMediaCarouselPresentation.slideChromeControlHeight
    }

    /// Expanded hit target for fish / buddy overlay icon buttons.
    static var taggedOverlayIconTapDimension: CGFloat {
        HomeMediaCarouselPresentation.taggedOverlayIconTapDimension
    }

    static func heroHeight(
        width: CGFloat,
        topSafeAreaInset: CGFloat,
        additionalBottomExtension: CGFloat = HomeLifetimeStatsLayout.heroBottomExtension
    ) -> CGFloat {
        HomeOverviewLayout.heroHeight(
            width: width,
            topSafeAreaInset: topSafeAreaInset,
            additionalBottomExtension: additionalBottomExtension
        )
    }

    /// Slide / **`TabView`** height when the parent **`PushedHeroBand`** applies **`-topSafeAreaInset`** bleed.
    /// Without this, fixed-height carousel content stops **`topSafeAreaInset`** pt above the band bottom (black gap above the stats sheet).
    static func carouselContentHeight(
        heroBandHeight: CGFloat,
        topSafeAreaInset: CGFloat,
        appliesOwnTopSafeAreaBleed: Bool
    ) -> CGFloat {
        appliesOwnTopSafeAreaBleed
            ? heroBandHeight
            : heroBandHeight + topSafeAreaInset
    }

    /// Feather under the status bar + **`AppHeader`** for readable chrome over bright media.
    static func headerGradientHeight(
        headerOverlayHeight: CGFloat,
        topSafeAreaInset: CGFloat,
        heroHeight: CGFloat
    ) -> CGFloat {
        let minimum = max(headerOverlayHeight, topSafeAreaInset + 56) + 96
        let extended = heroHeight * 0.52
        return max(minimum, extended)
    }
}

/// Animated hero stand-in when the Home carousel has no media to show.
struct HomeMediaCarouselEmptyPlaceholder: View {
    let containerWidth: CGFloat
    let topSafeAreaInset: CGFloat
    var headerOverlayHeight: CGFloat?
    var heroBandHeight: CGFloat?
    var context: HomeMediaCarouselEmptyPresentation.Context = .noMediaYet

    @Environment(\.openDiveImport) private var openDiveImport

    private var resolvedHeroBandHeight: CGFloat {
        heroBandHeight ?? HomeMediaCarouselLayout.heroHeight(
            width: containerWidth,
            topSafeAreaInset: topSafeAreaInset
        )
    }

    /// Always embedded in **`PushedHeroBand`** on Home — extend slide height for top safe-area bleed.
    private var resolvedCarouselContentHeight: CGFloat {
        HomeMediaCarouselLayout.carouselContentHeight(
            heroBandHeight: resolvedHeroBandHeight,
            topSafeAreaInset: topSafeAreaInset,
            appliesOwnTopSafeAreaBleed: false
        )
    }

    private var headline: String {
        HomeMediaCarouselEmptyPresentation.headline(for: context)
    }

    private var opensDiveImportFromHeadline: Bool {
        context == .noLoggedActivities && openDiveImport != nil
    }

    private var accessibilityPrompt: String {
        "\(headline). \(HomeMediaCarouselEmptyPresentation.message(for: context))"
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    AppTheme.Colors.surfaceGradientTop.opacity(0.92),
                    AppTheme.Colors.accent.opacity(0.14),
                    AppTheme.Colors.surfaceGradientBottom.opacity(0.96),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            MediaUploadEmptyGhostFramesAnimation(
                containerWidth: containerWidth,
                verticalOffset: HomeMediaCarouselEmptyPresentation.contentDownshift
            )
            .frame(width: containerWidth, height: resolvedCarouselContentHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)

            emptyHeroHeadline
                .frame(width: containerWidth, height: resolvedCarouselContentHeight, alignment: .bottom)
                .padding(.bottom, HomeMediaCarouselEmptyPresentation.ctaBottomInset)

            if let headerOverlayHeight {
                HomeMediaCarouselHeaderGradient(
                    height: HomeMediaCarouselLayout.headerGradientHeight(
                        headerOverlayHeight: headerOverlayHeight,
                        topSafeAreaInset: topSafeAreaInset,
                        heroHeight: resolvedHeroBandHeight
                    )
                )
                .allowsHitTesting(false)
            }
        }
        .frame(width: containerWidth, height: resolvedCarouselContentHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .modifier(HomeMediaCarouselTopSafeAreaBleedModifier(
            topSafeAreaInset: topSafeAreaInset,
            isEnabled: false
        ))
        .accessibilityIdentifier("Home.MediaCarousel.Empty")
    }

    @ViewBuilder
    private var emptyHeroHeadline: some View {
        if opensDiveImportFromHeadline, let openDiveImport {
            Button(action: openDiveImport) {
                LogYourFirstDiveGlassButtonLabel()
            }
            .logYourFirstDiveGlassButtonChrome()
            .accessibilityLabel(accessibilityPrompt)
            .accessibilityHint("Opens dive import")
            .accessibilityIdentifier("Home.MediaCarousel.Empty.LogFirstDive")
        } else {
            Text(headline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.mutedText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityPrompt)
        }
    }
}

/// When **`true`**, Home hero interaction chrome (fish overlay, buddy list) should sit above **`AppHeader`** hit testing.
enum HomeHeroInteractionOverlayKey: PreferenceKey {
    static var defaultValue: Bool = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

struct HomeMediaCarouselSection: View {
    let highlights: [HomeMediaHighlight]
    let mediaByID: [UUID: DiveMediaPhoto]
    let sightings: [SightingInstance]
    let marineLifeCatalog: [MarineLife]
    let taggedBuddyRowsByMediaID: [UUID: [DiveMediaBuddyTagPresentation.TaggedBuddyRow]]
    let ownerProfileID: UUID?
    let containerWidth: CGFloat
    let topSafeAreaInset: CGFloat
    let headerOverlayHeight: CGFloat
    var heroBandHeight: CGFloat?
    var appliesTopSafeAreaBleed: Bool = true
    let selfBuddyID: UUID?
    /// False while a pushed Home **`NavigationStack`** destination covers the hero.
    var isHeroPlaybackActive: Bool = true
    let onOpenDive: (UUID) -> Void
    let onOpenMedia: (UUID, UUID) -> Void
    let onOpenBuddy: (UUID) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var pagerSelectedIndex = 0
    @State private var isCarouselVisible = false
    @State private var marineLifeOverlayMediaID: UUID?
    @State private var selectedTaggedSpeciesUUID: String?
    @State private var expandedBuddyListMediaID: UUID?
    @State private var playbackResumeToken = 0
    @State private var loopingPagerResetTask: Task<Void, Never>?

    private var resolvedHeroBandHeight: CGFloat {
        heroBandHeight ?? HomeMediaCarouselLayout.heroHeight(
            width: containerWidth,
            topSafeAreaInset: topSafeAreaInset
        )
    }

    private var resolvedCarouselContentHeight: CGFloat {
        HomeMediaCarouselLayout.carouselContentHeight(
            heroBandHeight: resolvedHeroBandHeight,
            topSafeAreaInset: topSafeAreaInset,
            appliesOwnTopSafeAreaBleed: appliesTopSafeAreaBleed
        )
    }

    private var marineLifeOverlaySize: CGSize {
        HomeMediaCarouselPresentation.marineLifeOverlaySize(
            width: containerWidth,
            height: resolvedCarouselContentHeight
        )
    }

    private var showsMarineLifeOverlay: Bool {
        guard let mediaID = marineLifeOverlayMediaID else { return false }
        return !taggedSpecies(for: mediaID).isEmpty
    }

    private var isCarouselInteractionHold: Bool {
        HomeMediaCarouselPresentation.holdsSlideForInteraction(
            showsMarineLifeOverlay: showsMarineLifeOverlay,
            hasExpandedBuddyList: expandedBuddyListMediaID != nil
        )
    }

    private var isPlaybackAllowed: Bool {
        isCarouselVisible && isHeroPlaybackActive && scenePhase == .active
    }

    private var isAutoAdvanceEnabled: Bool {
        isPlaybackAllowed
            && HomeMediaCarouselPresentation.shouldAutoAdvance(slideCount: highlights.count)
            && !isCarouselInteractionHold
    }

    private var keepsAllSlidesLoaded: Bool {
        HomeMediaCarouselPresentation.keepsAllSlidesLoaded(slideCount: highlights.count)
    }

    private var pagerSlideCount: Int {
        HomeMediaCarouselPresentation.loopingPagerSlideCount(slideCount: highlights.count)
    }

    private var activeLogicalSlideIndex: Int {
        HomeMediaCarouselPresentation.logicalSlideIndex(
            pagerIndex: pagerSelectedIndex,
            slideCount: highlights.count
        )
    }

    private func isSlideActive(_ logicalIndex: Int) -> Bool {
        isPlaybackAllowed && activeLogicalSlideIndex == logicalIndex
    }

    /// Prefetch streaming players for the selected slide + **next** slide even before the carousel
    /// appears — otherwise slide **0** waits on visibility while others claim PhotoKit first.
    private func shouldPrepareVideo(for logicalIndex: Int) -> Bool {
        DiveMediaVideoPhotoKitGatePresentation.shouldPrepareCarouselVideo(
            logicalIndex: logicalIndex,
            activeLogicalIndex: activeLogicalSlideIndex,
            slideCount: highlights.count
        )
    }

    /// Playback must key off the **selected pager page** — the looping duplicate of slide **0**
    /// shares its logical index and must not bind/pause the shared muted player.
    private func isPagerPagePlaybackActive(_ pagerIndex: Int) -> Bool {
        isPlaybackAllowed
            && HomeMediaCarouselPresentation.isPagerPagePlaybackActive(
                pagerIndex: pagerIndex,
                selectedPagerIndex: pagerSelectedIndex
            )
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $pagerSelectedIndex) {
                ForEach(0..<pagerSlideCount, id: \.self) { pagerIndex in
                    let logicalIndex = HomeMediaCarouselPresentation.logicalSlideIndex(
                        pagerIndex: pagerIndex,
                        slideCount: highlights.count
                    )
                    let highlight = highlights[logicalIndex]
                    if let media = mediaByID[highlight.mediaID] {
                        let pagePlaybackActive = isPagerPagePlaybackActive(pagerIndex)
                        HomeMediaCarouselPage(
                            highlight: highlight,
                            media: media,
                            slideIndex: logicalIndex,
                            slideCount: highlights.count,
                            pageWidth: containerWidth,
                            pageHeight: resolvedCarouselContentHeight,
                            isVideoPlaybackActive: pagePlaybackActive,
                            shouldPrepareVideo: shouldPrepareVideo(for: logicalIndex),
                            isAutoAdvanceActive: isAutoAdvanceEnabled && pagePlaybackActive,
                            loopsSlidePlayback: HomeMediaCarouselPresentation.shouldLoopCarouselVideo(
                                isPagePlaybackActive: pagePlaybackActive
                            ),
                            playbackResumeToken: pagePlaybackActive ? playbackResumeToken : 0,
                            playbackAllowed: isPlaybackAllowed,
                            showsBottomChrome: !showsMarineLifeOverlay,
                            onSlideFinished: { finishSlide(at: logicalIndex) },
                            onOpenMedia: { onOpenMedia(highlight.diveActivityID, highlight.mediaID) },
                            onOpenDive: { onOpenDive(highlight.diveActivityID) },
                            onShowTaggedSpecies: { openMarineLifeOverlay(for: highlight.mediaID) },
                            taggedBuddies: taggedBuddyRowsByMediaID[highlight.mediaID] ?? [],
                            isBuddyListExpanded: expandedBuddyListMediaID == highlight.mediaID,
                            onToggleBuddyList: { toggleBuddyList(for: highlight.mediaID) },
                            selfBuddyID: selfBuddyID,
                            onOpenBuddy: onOpenBuddy
                        )
                        .tag(pagerIndex)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(width: containerWidth, height: resolvedCarouselContentHeight)
            .clipped()
            .onChange(of: pagerSelectedIndex) { oldIndex, newIndex in
                closeMarineLifeOverlay()
                closeBuddyList()
                loopingPagerResetTask?.cancel()
                if HomeMediaCarouselPresentation.shouldResetLoopingPagerIndex(
                    pagerIndex: newIndex,
                    slideCount: highlights.count
                ) {
                    // Defer the snap-back until the forward wrap animation / swipe settle
                    // finishes — an immediate non-animated jump here desyncs the paged
                    // TabView and leaves swipes on the first item unresponsive.
                    scheduleLoopingPagerReset()
                    logSlideSelection(
                        from: HomeMediaCarouselPresentation.logicalSlideIndex(
                            pagerIndex: oldIndex,
                            slideCount: highlights.count
                        ),
                        to: 0
                    )
                    return
                }
                logSlideSelection(
                    from: HomeMediaCarouselPresentation.logicalSlideIndex(
                        pagerIndex: oldIndex,
                        slideCount: highlights.count
                    ),
                    to: HomeMediaCarouselPresentation.logicalSlideIndex(
                        pagerIndex: newIndex,
                        slideCount: highlights.count
                    )
                )
            }

            if !showsMarineLifeOverlay {
                HomeMediaCarouselHeaderGradient(
                    height: HomeMediaCarouselLayout.headerGradientHeight(
                        headerOverlayHeight: headerOverlayHeight,
                        topSafeAreaInset: topSafeAreaInset,
                        heroHeight: resolvedHeroBandHeight
                    )
                )
                .allowsHitTesting(false)
            }

            if showsMarineLifeOverlay, let mediaID = marineLifeOverlayMediaID {
                let overlaySize = marineLifeOverlaySize
                let panelOverlap = HomeLifetimeStatsLayout.panelOverlap
                let closeTopInset = HomeMediaCarouselPresentation.marineLifeOverlayCloseTopInset(
                    topSafeAreaInset: topSafeAreaInset,
                    headerClearance: max(0, headerOverlayHeight - topSafeAreaInset)
                )
                let pageIndicatorBottomInset = HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorBottomInset(
                    overlayHeight: overlaySize.height,
                    heroBandHeight: resolvedHeroBandHeight,
                    topSafeAreaInset: topSafeAreaInset,
                    panelOverlap: panelOverlap
                )
                HomeMediaCarouselMarineLifeOverlay(
                    taggedSpecies: taggedSpecies(for: mediaID),
                    previewSize: overlaySize,
                    cornerRadius: HomeMediaCarouselPresentation.marineLifeOverlayCornerRadius,
                    ownerProfileID: ownerProfileID,
                    closeTopInset: closeTopInset,
                    pageIndicatorBottomInset: pageIndicatorBottomInset,
                    heroBandHeight: resolvedHeroBandHeight,
                    topSafeAreaInset: topSafeAreaInset,
                    panelOverlap: panelOverlap,
                    selectedSpeciesUUID: $selectedTaggedSpeciesUUID,
                    onOpenDive: onOpenDive,
                    onClose: closeMarineLifeOverlay
                )
                .frame(width: overlaySize.width, height: overlaySize.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(true)
                .transition(marineLifeOverlayTransition)
                .zIndex(3)
            }
        }
        .frame(maxWidth: .infinity)
        .modifier(HomeMediaCarouselTopSafeAreaBleedModifier(
            topSafeAreaInset: topSafeAreaInset,
            isEnabled: appliesTopSafeAreaBleed
        ))
        .animation(marineLifeOverlayAnimation, value: showsMarineLifeOverlay)
        .background {
            Color.clear
                .preference(
                    key: HomeHeroInteractionOverlayKey.self,
                    value: isCarouselInteractionHold
                )
        }
        .accessibilityIdentifier("Home.MediaCarousel")
        .onAppear {
            isCarouselVisible = true
            HomeMediaCarouselDebug.carouselVisibility(visible: true, slideCount: highlights.count)
            HomeMediaCarouselDebug.highlightsUpdated(
                mediaIDs: highlights.map(\.mediaID),
                keepsAllSlidesLoaded: keepsAllSlidesLoaded
            )
            logSlideSelection(from: activeLogicalSlideIndex, to: activeLogicalSlideIndex)
        }
        .onDisappear {
            isCarouselVisible = false
            loopingPagerResetTask?.cancel()
            loopingPagerResetTask = nil
            HomeMediaCarouselDebug.carouselVisibility(visible: false, slideCount: highlights.count)
        }
        .onChange(of: scenePhase) { _, phase in
            HomeMediaCarouselDebug.scenePhase(isActive: phase == .active)
        }
        .onChange(of: isPlaybackAllowed) { wasAllowed, isAllowed in
            if HomeMediaCarouselPresentation.shouldBumpPlaybackResumeWhenAllowed(
                wasPlaybackAllowed: wasAllowed,
                isPlaybackAllowed: isAllowed
            ) {
                invalidateCarouselVideoPlaybackHandoff()
                playbackResumeToken += 1
            }
        }
        .onChange(of: isHeroPlaybackActive) { wasActive, isActive in
            if wasActive, !isActive {
                closeMarineLifeOverlay()
                closeBuddyList()
            } else if !wasActive, isActive {
                closeMarineLifeOverlay()
                closeBuddyList()
            }
        }
    }

    private var marineLifeOverlayAnimation: Animation {
        .spring(response: 0.34, dampingFraction: 0.86)
    }

    private var buddyListAnimation: Animation {
        .spring(response: 0.34, dampingFraction: 0.82)
    }

    private var marineLifeOverlayTransition: AnyTransition {
        .opacity
    }

    private func taggedSpecies(for mediaID: UUID) -> [MarineLife] {
        HomeMediaCarouselPresentation.taggedSpecies(
            mediaID: mediaID,
            sightings: sightings,
            catalog: marineLifeCatalog
        )
    }

    private func openMarineLifeOverlay(for mediaID: UUID) {
        guard !taggedSpecies(for: mediaID).isEmpty else { return }
        closeBuddyList()
        selectedTaggedSpeciesUUID = taggedSpecies(for: mediaID).first?.uuid
        withAnimation(marineLifeOverlayAnimation) {
            marineLifeOverlayMediaID = mediaID
        }
    }

    private func closeMarineLifeOverlay() {
        guard marineLifeOverlayMediaID != nil else { return }
        withAnimation(marineLifeOverlayAnimation) {
            marineLifeOverlayMediaID = nil
            selectedTaggedSpeciesUUID = nil
        }
    }

    private func toggleBuddyList(for mediaID: UUID) {
        withAnimation(buddyListAnimation) {
            if expandedBuddyListMediaID == mediaID {
                expandedBuddyListMediaID = nil
            } else {
                marineLifeOverlayMediaID = nil
                selectedTaggedSpeciesUUID = nil
                expandedBuddyListMediaID = mediaID
            }
        }
    }

    private func closeBuddyList() {
        guard expandedBuddyListMediaID != nil else { return }
        withAnimation(buddyListAnimation) {
            expandedBuddyListMediaID = nil
        }
    }

    private func advanceToNextSlide() {
        guard HomeMediaCarouselPresentation.shouldAutoAdvance(slideCount: highlights.count) else { return }
        let next = HomeMediaCarouselPresentation.nextLoopingPagerIndex(
            after: pagerSelectedIndex,
            slideCount: highlights.count
        )
        withAnimation(.easeInOut(duration: HomeMediaCarouselPresentation.slideAdvanceAnimationSeconds)) {
            pagerSelectedIndex = next
        }
    }

    /// Snap the duplicate-first page back to index **0** once the wrap transition has settled.
    /// The duplicate renders identical slide-0 content (and owns playback while selected), so the
    /// user sees nothing; re-verifies the pager is still on the duplicate before jumping.
    private func scheduleLoopingPagerReset() {
        loopingPagerResetTask = Task { @MainActor in
            try? await Task.sleep(
                for: .seconds(HomeMediaCarouselPresentation.loopingPagerResetDelaySeconds)
            )
            guard !Task.isCancelled else { return }
            guard HomeMediaCarouselPresentation.shouldResetLoopingPagerIndex(
                pagerIndex: pagerSelectedIndex,
                slideCount: highlights.count
            ) else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                pagerSelectedIndex = 0
            }
        }
    }

    private func invalidateCarouselVideoPlaybackHandoff() {
        for sourceKey in HomeMediaCarouselPresentation.carouselVideoSourceIdentityKeys(
            highlights: highlights,
            mediaByID: mediaByID
        ) {
            DiveMediaVideoPlaybackSessionCache.shared.invalidateLibraryPlayback(
                sourceIdentityKey: sourceKey
            )
        }
    }

    /// Only the currently visible slide may advance the carousel (guards stale video end callbacks).
    private func finishSlide(at index: Int) {
        guard HomeMediaCarouselPresentation.shouldAdvanceFromSlide(
            selectedIndex: activeLogicalSlideIndex,
            finishingSlideIndex: index,
            isPlaybackAllowed: isPlaybackAllowed,
            holdsSlideForInteraction: isCarouselInteractionHold
        ) else { return }
        if HomeMediaCarouselPresentation.shouldRestartClipAfterPlaybackFinished(slideCount: highlights.count) {
            playbackResumeToken += 1
        } else {
            advanceToNextSlide()
        }
    }

    private func logSlideSelection(from oldIndex: Int, to newIndex: Int) {
        guard highlights.indices.contains(newIndex) else { return }
        let highlight = highlights[newIndex]
        let kind = mediaByID[highlight.mediaID]?.resolvedMediaKind.rawValue ?? "unknown"
        if oldIndex != newIndex {
            HomeMediaCarouselDebug.slideSelected(
                index: newIndex,
                slideCount: highlights.count,
                mediaID: highlight.mediaID,
                mediaKind: kind
            )
        }
        if highlights.indices.contains(oldIndex), oldIndex != newIndex,
           let oldMedia = mediaByID[highlights[oldIndex].mediaID] {
            HomeMediaCarouselDebug.slidePlayback(
                index: oldIndex,
                mediaID: oldMedia.id,
                isActive: false,
                playbackAllowed: isPlaybackAllowed,
                shouldLoad: keepsAllSlidesLoaded
            )
        }
        if let media = mediaByID[highlight.mediaID] {
            HomeMediaCarouselDebug.slidePlayback(
                index: newIndex,
                mediaID: media.id,
                isActive: isSlideActive(newIndex),
                playbackAllowed: isPlaybackAllowed,
                shouldLoad: keepsAllSlidesLoaded
            )
        }
    }
}

private struct HomeMediaCarouselHeaderGradient: View {
    let height: CGFloat

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.92), location: 0),
                .init(color: .black.opacity(0.72), location: 0.38),
                .init(color: .black.opacity(0.42), location: 0.68),
                .init(color: .black.opacity(0.14), location: 0.88),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct HomeMediaCarouselPage: View {
    let highlight: HomeMediaHighlight
    let media: DiveMediaPhoto
    let slideIndex: Int
    let slideCount: Int
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    var isVideoPlaybackActive: Bool
    /// Active or adjacent slides prepare streaming video; others wait so PhotoKit stays free.
    var shouldPrepareVideo: Bool = false
    var isAutoAdvanceActive: Bool
    var loopsSlidePlayback: Bool = false
    var playbackResumeToken: Int = 0
    var playbackAllowed: Bool = true
    var showsBottomChrome: Bool = true
    let onSlideFinished: () -> Void
    let onOpenMedia: () -> Void
    let onOpenDive: () -> Void
    let onShowTaggedSpecies: () -> Void
    let taggedBuddies: [DiveMediaBuddyTagPresentation.TaggedBuddyRow]
    let isBuddyListExpanded: Bool
    let onToggleBuddyList: () -> Void
    let selfBuddyID: UUID?
    let onOpenBuddy: (UUID) -> Void

    var body: some View {
        HomeMediaCarouselMediaView(
            media: media,
            slideIndex: slideIndex,
            slideCount: slideCount,
            containerWidth: pageWidth,
            isVideoPlaybackActive: isVideoPlaybackActive,
            shouldPrepareVideo: shouldPrepareVideo,
            isAutoAdvanceActive: isAutoAdvanceActive,
            loopsSlidePlayback: loopsSlidePlayback,
            playbackResumeToken: playbackResumeToken,
            playbackAllowed: playbackAllowed,
            onSlideFinished: onSlideFinished
        )
        .frame(width: pageWidth, height: pageHeight)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenMedia)
        .overlay(alignment: .bottom) {
            if showsBottomChrome {
                HomeMediaCarouselSlideBottomChrome(
                    highlight: highlight,
                    onOpenDive: onOpenDive,
                    onShowTaggedSpecies: onShowTaggedSpecies,
                    taggedBuddies: taggedBuddies,
                    isBuddyListExpanded: isBuddyListExpanded,
                    onToggleBuddyList: onToggleBuddyList,
                    selfBuddyID: selfBuddyID,
                    onOpenBuddy: onOpenBuddy
                )
                .frame(width: pageWidth)
            }
        }
        .frame(width: pageWidth, height: pageHeight)
        .accessibilityLabel("Dive media at \(highlight.siteDisplayName)")
    }
}

private struct HomeMediaCarouselSlideBottomChrome: View {
    let highlight: HomeMediaHighlight
    let onOpenDive: () -> Void
    let onShowTaggedSpecies: () -> Void
    let taggedBuddies: [DiveMediaBuddyTagPresentation.TaggedBuddyRow]
    let isBuddyListExpanded: Bool
    let onToggleBuddyList: () -> Void
    let selfBuddyID: UUID?
    let onOpenBuddy: (UUID) -> Void

    private enum Layout {
        static let gradientHeight: CGFloat = 112
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.md) {
            MediaDiveLinkChromeButton(
                siteDisplayName: highlight.siteDisplayName,
                diveNumberLabel: highlight.diveNumberLabel,
                linkedTripTitle: highlight.linkedTripTitle,
                action: onOpenDive
            )

            Spacer(minLength: AppTheme.Spacing.sm)

            if highlight.hasTaggedSpecies {
                HomeMediaCarouselTaggedSpeciesButton(
                    taggedCount: highlight.taggedSpeciesCount,
                    action: onShowTaggedSpecies
                )
            }

            if highlight.hasTaggedBuddies {
                HomeMediaCarouselTaggedBuddiesButton(
                    taggedBuddies: taggedBuddies,
                    taggedCount: highlight.taggedBuddyCount,
                    isExpanded: isBuddyListExpanded,
                    selfBuddyID: selfBuddyID,
                    onToggle: onToggleBuddyList,
                    onOpenBuddy: onOpenBuddy
                )
                .zIndex(isBuddyListExpanded ? 2 : 0)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, HomeMediaCarouselLayout.slideChromeBottomInset)
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
        .background(alignment: .bottom) {
            HomeMediaCarouselFooterGradient(height: Layout.gradientHeight)
                .allowsHitTesting(false)
        }
        .accessibilityIdentifier("Home.MediaCarousel.Overlay")
    }
}

private struct HomeMediaCarouselFooterGradient: View {
    let height: CGFloat

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.22), location: 0.45),
                .init(color: .black.opacity(0.62), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: max(height, 1))
        .frame(maxWidth: .infinity)
    }
}

private struct HomeMediaCarouselTaggedSpeciesButton: View {
    let taggedCount: Int
    let action: () -> Void

    private var controlHeight: CGFloat {
        HomeMediaCarouselLayout.slideChromeControlHeight
    }

    private var tapDimension: CGFloat {
        HomeMediaCarouselLayout.taggedOverlayIconTapDimension
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "fish.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .frame(width: controlHeight, height: controlHeight)
                    .appLiquidGlassCircleChrome()

                if taggedCount > 1 {
                    MediaTagCountBadge(count: taggedCount)
                }
            }
            .frame(width: tapDimension, height: tapDimension, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(taggedCount > 1 ? "\(taggedCount) tagged species" : "Tagged marine life")
        .accessibilityHint("Shows species tagged on this photo")
        .accessibilityIdentifier("Home.MediaCarousel.TaggedSpecies")
    }
}

private struct HomeMediaCarouselTaggedBuddiesButton: View {
    let taggedBuddies: [DiveMediaBuddyTagPresentation.TaggedBuddyRow]
    let taggedCount: Int
    let isExpanded: Bool
    let selfBuddyID: UUID?
    let onToggle: () -> Void
    let onOpenBuddy: (UUID) -> Void

    private enum Layout {
        static var iconDiameter: CGFloat { HomeMediaCarouselLayout.slideChromeControlHeight }
        static var iconTapDimension: CGFloat { HomeMediaCarouselLayout.taggedOverlayIconTapDimension }
        static var avatarDiameter: CGFloat { max(iconDiameter - 4, 32) }
        static let avatarSpacing: CGFloat = 8
        /// How far the buddy stack rises from the icon when expanding.
        static let iconAnchorRise: CGFloat = 12
        static let staggerDelayStep: TimeInterval = 0.055
        static var maxAnimatedRevealCount: Int {
            min(
                HomeMediaCarouselPresentation.taggedBuddyMaxFullVisibleProfiles + 1,
                3
            )
        }
    }

    private var buddyExpandAnimation: Animation {
        .spring(response: 0.4, dampingFraction: 0.76)
    }

    private var expandedBuddyListHeight: CGFloat {
        HomeMediaCarouselPresentation.taggedBuddyExpandedListHeight(
            buddyCount: taggedBuddies.count,
            avatarDiameter: Layout.avatarDiameter,
            avatarSpacing: Layout.avatarSpacing
        )
    }

    private var showsBuddyScrollFade: Bool {
        isExpanded && HomeMediaCarouselPresentation.taggedBuddyListShowsScrollFade(
            buddyCount: taggedBuddies.count
        )
    }

    private func collapsedBuddyOffset(index: Int, total: Int) -> CGFloat {
        let avatarsBelow = (total - 1) - index
        let stackBelowHeight = CGFloat(avatarsBelow) * (Layout.avatarDiameter + Layout.avatarSpacing)
        return stackBelowHeight + Layout.iconDiameter + Layout.iconAnchorRise
    }

    private func buddyRevealDelay(index: Int, total: Int) -> TimeInterval {
        Double(total - 1 - index) * Layout.staggerDelayStep
    }

    @State private var buddyScrollContentOffset: CGFloat = 0

    private var iconColor: Color {
        isExpanded ? AppTheme.Colors.tabUnselected : AppTheme.Colors.accent
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            expandedBuddyList
                .padding(.bottom, Layout.iconDiameter + Layout.avatarSpacing)
                .allowsHitTesting(isExpanded)
                .accessibilityHidden(!isExpanded)

            Button(action: onToggle) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "person.2.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: Layout.iconDiameter, height: Layout.iconDiameter)
                        .appLiquidGlassCircleChrome()

                    if taggedCount > 1, !isExpanded {
                        MediaTagCountBadge(count: taggedCount)
                    }
                }
                .frame(width: Layout.iconTapDimension, height: Layout.iconTapDimension, alignment: .center)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(buddyExpandAnimation, value: isExpanded)
            .accessibilityLabel(
                isExpanded
                    ? "Hide tagged buddies"
                    : (taggedCount > 1 ? "\(taggedCount) tagged buddies" : "Tagged buddies")
            )
            .accessibilityHint(isExpanded ? "Collapses the buddy list" : "Shows buddies tagged on this photo")
            .accessibilityIdentifier("Home.MediaCarousel.TaggedBuddies")
        }
        .frame(minWidth: Layout.iconTapDimension, minHeight: Layout.iconTapDimension, alignment: .bottom)
    }

    @ViewBuilder
    private var expandedBuddyList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Layout.avatarSpacing) {
                ForEach(Array(taggedBuddies.enumerated()), id: \.element.id) { index, buddy in
                    HomeMediaCarouselTaggedBuddyScrollRow(
                        buddy: buddy,
                        index: index,
                        buddyCount: taggedBuddies.count,
                        isExpanded: isExpanded,
                        viewportHeight: expandedBuddyListHeight,
                        avatarDiameter: Layout.avatarDiameter,
                        avatarSpacing: Layout.avatarSpacing,
                        scrollContentOffset: buddyScrollContentOffset,
                        selfBuddyID: selfBuddyID,
                        collapsedOffset: collapsedBuddyOffset(
                            index: min(index, Layout.maxAnimatedRevealCount - 1),
                            total: min(taggedBuddies.count, Layout.maxAnimatedRevealCount)
                        ),
                        revealDelay: buddyRevealDelay(
                            index: min(index, Layout.maxAnimatedRevealCount - 1),
                            total: min(taggedBuddies.count, Layout.maxAnimatedRevealCount)
                        ),
                        expandAnimation: buddyExpandAnimation,
                        onOpenBuddy: onOpenBuddy
                    )
                }
            }
            .padding(.vertical, 2)
        }
        .coordinateSpace(name: "buddyListViewport")
        .defaultScrollAnchor(.bottom)
        .scrollClipDisabled(true)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, offsetY in
            buddyScrollContentOffset = offsetY
        }
        .frame(height: expandedBuddyListHeight)
        .accessibilityHint(showsBuddyScrollFade ? "Scroll to see more tagged buddies" : "")
    }
}

private struct HomeMediaCarouselTaggedBuddyScrollRow: View {
    let buddy: DiveMediaBuddyTagPresentation.TaggedBuddyRow
    let index: Int
    let buddyCount: Int
    let isExpanded: Bool
    let viewportHeight: CGFloat
    let avatarDiameter: CGFloat
    let avatarSpacing: CGFloat
    let scrollContentOffset: CGFloat
    let selfBuddyID: UUID?
    let collapsedOffset: CGFloat
    let revealDelay: TimeInterval
    let expandAnimation: Animation
    let onOpenBuddy: (UUID) -> Void

    @State private var viewportFrame: CGRect = .zero

    private var fadeMask: HomeMediaCarouselPresentation.BuddyRowFadeMask {
        _ = scrollContentOffset
        return HomeMediaCarouselPresentation.buddyRowFadeMask(
            rowMinYInViewport: viewportFrame.minY,
            rowMaxYInViewport: viewportFrame.maxY,
            viewportHeight: viewportHeight,
            avatarDiameter: avatarDiameter,
            avatarSpacing: avatarSpacing,
            buddyCount: buddyCount
        )
    }

    var body: some View {
        Button {
            onOpenBuddy(buddy.buddyID)
        } label: {
            buddyAvatar
                .compositingGroup()
                .mask(alignment: .top) {
                    buddyAvatarFadeMask
                }
        }
        .buttonStyle(.plain)
        .opacity(fadeMask.isHidden ? 0 : (isExpanded ? 1 : 0))
        .allowsHitTesting(isExpanded && !fadeMask.isHidden)
        .offset(y: isExpanded ? 0 : collapsedOffset)
        .animation(expandAnimation.delay(revealDelay), value: isExpanded)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        scheduleViewportFrameUpdate(geometry.frame(in: .named("buddyListViewport")))
                    }
                    .onChange(of: geometry.frame(in: .named("buddyListViewport"))) { _, frame in
                        scheduleViewportFrameUpdate(frame)
                    }
            }
        }
        .accessibilityLabel(buddy.displayName)
        .accessibilityHint(
            DiveBuddySelfRepresentation.isSelfBuddyID(
                buddy.buddyID,
                selfBuddyID: selfBuddyID
            )
                ? "Opens your profile"
                : "Opens buddy overview"
        )
        .accessibilityIdentifier("Home.MediaCarousel.TaggedBuddy.\(buddy.buddyID.uuidString)")
    }

    private func scheduleViewportFrameUpdate(_ frame: CGRect) {
        guard frame != viewportFrame else { return }
        Task { @MainActor in
            viewportFrame = frame
        }
    }

    private var buddyAvatar: some View {
        ProfileAvatarView(
            profilePhoto: buddy.profilePhoto,
            diameter: avatarDiameter,
            iconFont: .callout,
            placeholderInitials: DiveBuddyPresentation.initials(from: buddy.displayName)
        )
        .background {
            Circle()
                .fill(.black.opacity(0.42))
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                }
                .clipShape(Circle())
        }
        .frame(width: avatarDiameter, height: avatarDiameter)
    }

    private var buddyAvatarFadeMask: some View {
        VStack(spacing: 0) {
            if fadeMask.transparentTopHeight > 0 {
                Color.clear
                    .frame(height: fadeMask.transparentTopHeight)
            }
            if fadeMask.fadeHeight > 0 {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fadeMask.fadeHeight)
            }
            if fadeMask.opaqueBottomHeight > 0 {
                Rectangle()
                    .fill(.black)
                    .frame(height: fadeMask.opaqueBottomHeight)
            }
        }
        .frame(width: avatarDiameter, height: avatarDiameter)
    }
}

/// Home carousel media — reads session-cached hero frames synchronously; videos use warmed **`AVAsset`**s.
private struct HomeMediaCarouselMediaView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayScale) private var displayScale
    @Environment(AppNetworkConnectivityMonitor.self) private var networkConnectivity

    let media: DiveMediaPhoto
    var slideIndex: Int = 0
    var slideCount: Int = 1
    var containerWidth: CGFloat = HomeMediaHighlightWarmupPresentation.defaultHeroContainerWidth
    var isVideoPlaybackActive: Bool
    var shouldPrepareVideo: Bool = false
    var isAutoAdvanceActive: Bool
    var loopsSlidePlayback: Bool = false
    var playbackResumeToken: Int = 0
    var playbackAllowed: Bool = true
    let onSlideFinished: () -> Void

    #if canImport(UIKit)
    @State private var loadedImage: UIImage?
    @State private var heroImageLoadFinished = false
    @State private var homeCarouselPlayerTick = 0
    #endif

    private var isVideo: Bool {
        media.resolvedMediaKind == .video
    }

    @ViewBuilder
    private var homeCarouselVideoLayer: some View {
        #if canImport(UIKit) && canImport(AVFoundation)
        if let identifier = media.libraryAssetLocalIdentifier,
           let player = HomeCarouselVideoSessionCache.shared.player(forLibraryIdentifier: identifier) {
            HomeCarouselMutedVideoPlayer(
                player: player,
                isPlaybackActive: isVideoPlaybackActive,
                loopsPlayback: loopsSlidePlayback,
                onPlaybackFinished: nil
            )
            .id("\(identifier)-player-\(homeCarouselPlayerTick)")
        }
        // Soft / session poster remains underneath until the player is ready.
        #endif
    }

    var body: some View {
        ZStack {
            photoContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(isVideo && isVideoPlaybackActive)

            if isVideo && isVideoPlaybackActive {
                homeCarouselVideoLayer
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id("\(media.id)-resume-\(playbackResumeToken)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear {
            DiveMediaPreviewStorage.seedSessionCacheIfNeeded(for: media)
            logVideoLayer(mounted: isVideo)
        }
        .onDisappear {
            logVideoLayer(mounted: false)
        }
        .onChange(of: isVideoPlaybackActive) { _, isActive in
            HomeMediaCarouselDebug.slidePlayback(
                index: slideIndex,
                mediaID: media.id,
                isActive: isActive,
                playbackAllowed: playbackAllowed,
                shouldLoad: true
            )
            logVideoLayer(mounted: isVideo && isActive)
            #if canImport(UIKit) && canImport(AVFoundation)
            let hasPlayer = media.libraryAssetLocalIdentifier.map {
                HomeCarouselVideoSessionCache.shared.player(forLibraryIdentifier: $0) != nil
            } ?? false
            if HomeMediaCarouselPresentation.shouldRemountCarouselPlayerWhenBecomingActive(
                isBecomingActive: isActive,
                hasPreparedPlayer: hasPlayer
            ) {
                homeCarouselPlayerTick += 1
            }
            #endif
        }
        .task(id: loadTaskID) {
            await loadHeroImageIfNeeded()
        }
        .task(id: "\(media.id.uuidString)-video-\(shouldPrepareVideo)") {
            guard isVideo,
                  DiveMediaVideoPhotoKitGatePresentation.shouldEnsureCarouselVideoReady(
                      isSlidePlaybackActive: shouldPrepareVideo
                  ) else { return }
            await HomeMediaHighlightWarmup.ensureCarouselVideoReady(for: media)
            homeCarouselPlayerTick += 1
            #if canImport(UIKit) && canImport(AVFoundation)
            _ = DiveMediaLibraryIdentifierRepair.resolveLocalIdentifierIfNeeded(
                for: media,
                modelContext: modelContext
            )
            guard let identifier = media.libraryAssetLocalIdentifier else { return }
            // Soft-timeout races: PhotoKit may still deliver after ensure returns nil.
            if HomeCarouselVideoSessionCache.shared.player(forLibraryIdentifier: identifier) == nil {
                for _ in 0 ..< 8 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled else { return }
                    if HomeCarouselVideoSessionCache.shared.player(forLibraryIdentifier: identifier) != nil {
                        homeCarouselPlayerTick += 1
                        return
                    }
                }
                await loadHeroImageIfNeeded(forceStillUpgradeAfterFailedVideo: true)
            }
            #endif
        }
        .task(id: photoAutoAdvanceTaskID) {
            await runPhotoAutoAdvanceIfNeeded()
        }
        .task(id: videoAutoAdvanceTaskID) {
            await runVideoAutoAdvanceIfNeeded()
        }
    }

    private var photoAutoAdvanceTaskID: String {
        "\(media.id.uuidString)-photo-auto-\(isAutoAdvanceActive)-\(playbackResumeToken)"
    }

    private var videoAutoAdvanceTaskID: String {
        "\(media.id.uuidString)-video-auto-\(isAutoAdvanceActive)-\(playbackResumeToken)-\(homeCarouselPlayerTick)"
    }

    private func runPhotoAutoAdvanceIfNeeded() async {
        guard isAutoAdvanceActive, !isVideo else { return }
        let seconds = HomeMediaCarouselPresentation.photoDisplaySeconds
        try? await Task.sleep(for: .seconds(seconds))
        guard !Task.isCancelled, isAutoAdvanceActive else { return }
        onSlideFinished()
    }

    private func runVideoAutoAdvanceIfNeeded() async {
        guard isAutoAdvanceActive, isVideo else { return }
        #if canImport(AVFoundation)
        let assetDuration: Double? = {
            guard let identifier = media.libraryAssetLocalIdentifier,
                  let player = HomeCarouselVideoSessionCache.shared.player(forLibraryIdentifier: identifier),
                  let item = player.currentItem else { return nil }
            let seconds = CMTimeGetSeconds(item.duration)
            return seconds.isFinite && seconds > 0 ? seconds : nil
        }()
        #else
        let assetDuration: Double? = nil
        #endif
        guard let seconds = HomeMediaCarouselPresentation.videoAutoAdvanceSeconds(
            assetDurationSeconds: assetDuration,
            slideCount: slideCount
        ) else { return }
        try? await Task.sleep(for: .seconds(seconds))
        guard !Task.isCancelled, isAutoAdvanceActive else { return }
        onSlideFinished()
    }

    private var loadTaskID: String {
        "\(media.id.uuidString)-\(media.resolvedMediaKind.rawValue)-\(HomeMediaCarouselPresentation.stableImageLoadWidthKey(containerWidth))"
    }

    @ViewBuilder
    private var photoContent: some View {
        #if canImport(UIKit)
        if let displayImage = resolvedHeroDisplayImage {
            Image(uiImage: displayImage)
                .resizable()
                .scaledToFill()
                .accessibilityLabel("Dive photo")
        } else if DiveMediaPreviewPersistence.showsMissingMediaPlaceholder(
            hasDisplayedImage: resolvedHeroDisplayImage != nil,
            loadFinished: heroImageLoadFinished
        ) {
            heroPlaceholder
        } else {
            heroLoadingPlaceholder
        }
        #else
        heroPlaceholder
        #endif
    }

    #if canImport(UIKit)
    private var resolvedHeroDisplayImage: UIImage? {
        DiveMediaProgressivePresentation.preferredStillImage(
            progressive: loadedImage,
            sessionCached: sessionCachedImage,
            storedPreview: storedPreviewImage
        )
    }

    private var storedPreviewImage: UIImage? {
        DiveMediaPreviewStorage.storedPreviewImage(for: media)
    }
    #endif

    #if canImport(UIKit)
    private var sessionCachedImage: UIImage? {
        guard let identifier = media.libraryAssetLocalIdentifier else { return nil }
        return HomeMediaHighlightSessionCache.shared.bestCachedImage(localIdentifier: identifier)
    }
    #endif

    private var heroPlaceholder: some View {
        ZStack {
            AppTheme.Colors.surfaceMuted.opacity(0.5)
            if !networkConnectivity.isConnected {
                OfflineMediaUnavailableIndicator()
            }
        }
    }

    private var heroLoadingPlaceholder: some View {
        AppTheme.Colors.surfaceMuted.opacity(0.35)
    }

    #if canImport(UIKit)
    private func loadHeroImageIfNeeded(forceStillUpgradeAfterFailedVideo: Bool = false) async {
        _ = DiveMediaLibraryIdentifierRepair.resolveLocalIdentifierIfNeeded(
            for: media,
            modelContext: modelContext
        )
        let libraryIdentifier = media.libraryAssetLocalIdentifier
        let hadSessionHero = libraryIdentifier.map {
            HomeMediaHighlightSessionCache.shared.containsImage(
                localIdentifier: $0,
                edge: HomeMediaHighlightWarmup.preloadImageEdge
            )
        } ?? false
        let hadSessionPreview = libraryIdentifier.map {
            HomeMediaHighlightSessionCache.shared.bestCachedImage(localIdentifier: $0) != nil
        } ?? false
        let hadStoredPreview = DiveMediaPreviewStorage.hasStoredPreview(for: media)

        HomeMediaCarouselDebug.loadTaskBegan(
            index: slideIndex,
            mediaID: media.id,
            mediaKind: media.resolvedMediaKind.rawValue,
            libraryIdentifier: libraryIdentifier,
            hadSessionHero: hadSessionHero,
            hadSessionPreview: hadSessionPreview,
            hadStoredPreview: hadStoredPreview,
            containerWidth: containerWidth
        )

        DiveMediaPreviewStorage.seedSessionCacheIfNeeded(for: media)

        if loadedImage == nil {
            loadedImage = sessionCachedImage ?? storedPreviewImage
        }

        // Soft/session poster is enough while AVAsset resolves — don't race PhotoKit stills vs video.
        // After a failed prepare, `forceStillUpgradeAfterFailedVideo` allows a poster upgrade.
        if !forceStillUpgradeAfterFailedVideo,
           HomeMediaHighlightWarmupPresentation.shouldSkipStillPhotoKitLoadWhileVideoResolves(
            isVideo: isVideo,
            hasDisplayablePoster: resolvedHeroDisplayImage != nil,
            isVideoPrepareInFlightOrReady: shouldPrepareVideo
        ) {
            heroImageLoadFinished = true
            HomeMediaCarouselDebug.loadTaskEnded(
                index: slideIndex,
                mediaID: media.id,
                outcome: .storedPreviewHit,
                hadDisplayedImage: true
            )
            return
        }

        guard let identifier = libraryIdentifier else {
            heroImageLoadFinished = true
            HomeMediaCarouselDebug.loadTaskEnded(
                index: slideIndex,
                mediaID: media.id,
                outcome: .missingLibraryIdentifier,
                hadDisplayedImage: resolvedHeroDisplayImage != nil
            )
            if DiveMediaCloudIdentifierStorage.isPresent(media.photosCloudIdentifier) {
                DiveMediaReferencePruning.pruneIfAssetMissing(media, modelContext: modelContext)
            }
            return
        }

        let stableWidth = HomeMediaCarouselPresentation.stableImageLoadWidth(containerWidth)
        // Videos only need a poster still — requesting hero-sized frames competes with AVAsset loads.
        let targetEdge: CGFloat
        if isVideo || !networkConnectivity.isConnected {
            targetEdge = HomeMediaHighlightWarmupPresentation.previewImageEdge
        } else {
            targetEdge = HomeMediaHighlightWarmupPresentation.heroImageEdge(containerWidth: stableWidth)
        }
        let targetSize = CGSize(width: targetEdge, height: targetEdge)
        let hasCachedImageAtTargetEdge = HomeMediaHighlightSessionCache.shared.containsImage(
            localIdentifier: identifier,
            edge: targetEdge
        )

        if hasCachedImageAtTargetEdge, let cachedHero = HomeMediaHighlightSessionCache.shared.image(
            for: identifier,
            edge: targetEdge
        ) {
            loadedImage = cachedHero
            heroImageLoadFinished = true
            HomeMediaCarouselDebug.loadTaskEnded(
                index: slideIndex,
                mediaID: media.id,
                outcome: .sessionHeroHit,
                hadDisplayedImage: true
            )
            return
        }

        if loadedImage == nil {
            loadedImage = sessionCachedImage ?? storedPreviewImage
        }

        guard HomeMediaHighlightWarmupPresentation.shouldLoadHeroImage(
            hasCachedImageAtTargetEdge: hasCachedImageAtTargetEdge
        ) else {
            heroImageLoadFinished = loadedImage != nil
            HomeMediaCarouselDebug.loadTaskEnded(
                index: slideIndex,
                mediaID: media.id,
                outcome: loadedImage != nil ? .sessionPreviewHit : .loadFailed,
                hadDisplayedImage: resolvedHeroDisplayImage != nil
            )
            return
        }

        if loadedImage == nil {
            heroImageLoadFinished = false
        }

        var receivedFinal = false
        await DiveMediaReferenceLoader.loadImageProgressive(
            localIdentifier: identifier,
            targetSize: targetSize,
            deliveryMode: .opportunistic
        ) { image, isFinal in
            loadedImage = image
            if isFinal {
                receivedFinal = true
                DiveMediaPreviewStorage.persistPreview(from: image, on: media, modelContext: modelContext)
                heroImageLoadFinished = true
            }
        }

        if Task.isCancelled {
            HomeMediaCarouselDebug.loadTaskEnded(
                index: slideIndex,
                mediaID: media.id,
                outcome: .loadTaskCancelled,
                hadDisplayedImage: resolvedHeroDisplayImage != nil
            )
            return
        }

        if loadedImage != nil {
            heroImageLoadFinished = true
            _ = DiveMediaLibraryIdentifierRepair.captureCloudIdentifierIfNeeded(for: media)
            try? modelContext.save()
            HomeMediaCarouselDebug.loadTaskEnded(
                index: slideIndex,
                mediaID: media.id,
                outcome: receivedFinal ? .progressiveFinal : .progressivePartial,
                hadDisplayedImage: true
            )
        } else if networkConnectivity.isConnected {
            DiveMediaReferencePruning.pruneIfAssetMissing(media, modelContext: modelContext)
            HomeMediaCarouselDebug.loadTaskEnded(
                index: slideIndex,
                mediaID: media.id,
                outcome: .loadFailed,
                hadDisplayedImage: false
            )
        } else {
            HomeMediaCarouselDebug.loadTaskEnded(
                index: slideIndex,
                mediaID: media.id,
                outcome: .loadFailed,
                hadDisplayedImage: false
            )
        }
    }

    private func logVideoLayer(mounted: Bool) {
        guard isVideo else { return }
        HomeMediaCarouselDebug.videoLayer(
            index: slideIndex,
            mediaID: media.id,
            mounted: mounted,
            isPlaybackActive: isVideoPlaybackActive
        )
    }
    #else
    private func loadHeroImageIfNeeded() async {}
    #endif

    private func pruneIfAssetMissing() {
        #if canImport(Photos)
        DiveMediaReferencePruning.pruneIfAssetMissing(media, modelContext: modelContext)
        #endif
    }
}

// MARK: - Lifetime stats

enum HomeLifetimeStatsLayout {
    static let gridColumnCount = HomeLifetimeStatsTilesLayout.gridColumnCount
    static let gridSpacing = HomeLifetimeStatsTilesLayout.gridSpacing
    /// Fixed height per highlight stat card (intrinsic grid — no **`GeometryReader`** stretch).
    static let statTileHeight: CGFloat = HomeLifetimeStatsTilesLayout.statTileHeight
    static let statTileCornerRadius: CGFloat = 12
    static let statTilePadding: CGFloat = HomeLifetimeStatsTilesLayout.statTilePadding

    /// Matches modal / embedded sheet corner radius — stats panel reads as a sheet over the hero.
    static let panelTopCornerRadius: CGFloat = AppTheme.Sheet.cornerRadius
    /// How far the stats panel rises over featured media (media shows through the top corner radii).
    static let panelOverlap: CGFloat = HomeOverviewLayout.panelOverlap
    /// Extra hero height below the base aspect ratio so media bleeds behind the stats sheet.
    static let heroBottomExtension: CGFloat = HomeOverviewLayout.heroBottomExtension
    static let panelTopContentPadding: CGFloat = AppTheme.Spacing.lg
    /// In-panel top inset when overlapping media — UI only (hero seam uses **`HomeLifetimeStatsTilesLayout`** estimates).
    static let panelTopContentPaddingWhenOverlapping = HomeLifetimeStatsTilesLayout.panelTopContentPaddingWhenOverlapping
    /// Extra inset above the tab bar for panel content (tab bar clearance is added separately).
    static let panelBottomContentPadding = HomeLifetimeStatsTilesLayout.panelBottomContentPadding

    static func rowCount(tileCount: Int) -> Int {
        guard tileCount > 0 else { return 0 }
        return (tileCount + gridColumnCount - 1) / gridColumnCount
    }

    /// Highlight stat slots on Home (deepest, longest, top site, top species).
    static let highlightStatTileCount = 4

    static let estimatedBuddyLeaderboardHeight: CGFloat = HomeBuddyLeaderboardLayout.estimatedTileHeight

    static func gridHeight(tileCount: Int) -> CGFloat {
        let rows = rowCount(tileCount: tileCount)
        guard rows > 0 else { return 0 }
        return CGFloat(rows) * statTileHeight + gridSpacing * CGFloat(max(rows - 1, 0))
    }

    nonisolated static func estimatedScrollContentHeight(showsBuddyLeaderboard: Bool) -> CGFloat {
        HomeLifetimeStatsPanelLayout.estimatedScrollContentHeight(showsBuddyLeaderboard: showsBuddyLeaderboard)
    }

    nonisolated static func estimatedPanelContentHeight(showsBuddyLeaderboard: Bool) -> CGFloat {
        HomeLifetimeStatsPanelLayout.estimatedPanelContentHeight(showsBuddyLeaderboard: showsBuddyLeaderboard)
    }

    static func valueFontSize() -> CGFloat { HomeLifetimeStatsTilesLayout.valueFontSize }
    static func titleFontSize() -> CGFloat { HomeLifetimeStatsTilesLayout.titleFontSize }

    static func resolvedVerticalEdgeInsets(
        totalHeight: CGFloat,
        statRowCount: Int,
        showsBuddyLeaderboard: Bool
    ) -> (top: CGFloat, bottom: CGFloat) {
        HomeLifetimeStatsTilesLayout.resolvedVerticalEdgeInsets(
            totalHeight: totalHeight,
            statRowCount: statRowCount,
            showsBuddyLeaderboard: showsBuddyLeaderboard
        )
    }

    static func resolvedVerticalEdgeInset(
        totalHeight: CGFloat,
        statRowCount: Int,
        showsBuddyLeaderboard: Bool
    ) -> CGFloat {
        HomeLifetimeStatsTilesLayout.resolvedVerticalEdgeInset(
            totalHeight: totalHeight,
            statRowCount: statRowCount,
            showsBuddyLeaderboard: showsBuddyLeaderboard
        )
    }

    static func resolvedFlexibleLayoutHeights(
        totalHeight: CGFloat,
        statRowCount: Int,
        showsBuddyLeaderboard: Bool
    ) -> (statRowHeight: CGFloat, buddyRowHeight: CGFloat) {
        HomeLifetimeStatsTilesLayout.resolvedFlexibleLayoutHeights(
            totalHeight: totalHeight,
            statRowCount: statRowCount,
            showsBuddyLeaderboard: showsBuddyLeaderboard
        )
    }

    static func resolvedFlexibleSectionHeights(
        totalHeight: CGFloat,
        showsBuddyLeaderboard: Bool
    ) -> (grid: CGFloat, buddy: CGFloat) {
        HomeLifetimeStatsTilesLayout.resolvedFlexibleSectionHeights(
            totalHeight: totalHeight,
            showsBuddyLeaderboard: showsBuddyLeaderboard
        )
    }
}

/// Flip flags to **`false`** (or remove overlays) when Home sheet layout debugging is done.
private enum HomeSheetContainerDebug {
    static let usesPinkBackground = false
    /// Temporary guide lines on the Home tab-root stats panel — spacing / tile placement.
    static let showsLayoutGuides = false
}

/// Sheet-style chrome for Home lifetime stats — rounded top, opaque fill, optional hero overlap.
struct HomeLifetimeStatsPanel<Content: View>: View {
    var overlapsMedia: Bool
    /// Keeps tiles above the tab bar while the panel fill extends to the viewport bottom.
    var bottomSafeAreaInset: CGFloat = 0
    /// Temporary Home-only seam debug — set **`HomeSheetContainerDebug.usesPinkBackground`** to **`false`** to restore blue.
    var usesHomeDebugPanelTint: Bool = false
    /// Home tab root applies list inset here; pushed detail pages use **`BlueSheetDetailPage`** shell padding instead.
    var appliesHorizontalContentPadding: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        panelContent
            .padding(
                .top,
                overlapsMedia
                    ? HomeLifetimeStatsLayout.panelTopContentPaddingWhenOverlapping
                    : HomeLifetimeStatsLayout.panelTopContentPadding
            )
            .padding(.bottom, HomeLifetimeStatsLayout.panelBottomContentPadding + bottomSafeAreaInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                Group {
                    if usesHomeDebugPanelTint, HomeSheetContainerDebug.usesPinkBackground {
                        Color.pink
                    } else {
                        AppOverviewSheetPanelBackground()
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .clipShape(panelShape)
            .overlay {
                if usesHomeDebugPanelTint, HomeSheetContainerDebug.showsLayoutGuides {
                    HomeLifetimeStatsPanelOuterLayoutGuides(
                        bottomSafeAreaInset: bottomSafeAreaInset,
                        topPadding: overlapsMedia
                            ? HomeLifetimeStatsLayout.panelTopContentPaddingWhenOverlapping
                            : HomeLifetimeStatsLayout.panelTopContentPadding
                    )
                }
            }
            .shadow(
                color: .black.opacity(overlapsMedia ? 0.14 : 0.08),
                radius: overlapsMedia ? 16 : 8,
                y: overlapsMedia ? -6 : -2
            )
            .accessibilityIdentifier("Home.LifetimeStats.Panel")
    }

    @ViewBuilder
    private var panelContent: some View {
        if appliesHorizontalContentPadding {
            content()
                .padding(.horizontal, AppTheme.Spacing.lg)
        } else {
            content()
        }
    }

    private var panelShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: HomeLifetimeStatsLayout.panelTopCornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: HomeLifetimeStatsLayout.panelTopCornerRadius
        )
    }
}

// MARK: - Temporary Home stats layout guides (remove when tile placement is settled)

/// Panel-level bands: padded content slot vs tab-bar reserve below tiles.
private struct HomeLifetimeStatsPanelOuterLayoutGuides: View {
    let bottomSafeAreaInset: CGFloat
    let topPadding: CGFloat
    var estimatedTabBarClearance: CGFloat = RootTabBarLayoutMeasurement.estimatedClearanceAboveTabBar(
        safeAreaBottom: 0
    )

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let contentTop = topPadding
            let tabReserveTop = max(height - bottomSafeAreaInset, contentTop)
            let estimatedReserveTop = max(height - estimatedTabBarClearance, contentTop)
            let usesMeasuredTabBar = bottomSafeAreaInset > 0
                && abs(bottomSafeAreaInset - estimatedTabBarClearance) > 1

            ZStack(alignment: .topLeading) {
                if bottomSafeAreaInset > 0 {
                    Rectangle()
                        .fill(Color.red.opacity(0.14))
                        .frame(height: max(height - tabReserveTop, 0))
                        .offset(y: tabReserveTop)
                }

                HomeLifetimeStatsLayoutGuideLine(
                    label: "PANEL TOP (sheet seam)",
                    color: .white
                )

                if topPadding > 0.5 {
                    HomeLifetimeStatsLayoutGuideLine(
                        label: "PANEL PADDING TOP \(Int(topPadding))pt",
                        color: .white.opacity(0.7)
                    )
                    .offset(y: topPadding)
                }

                HomeLifetimeStatsLayoutGuideLine(
                    label: "CONTENT SLOT TOP",
                    color: .yellow
                )
                .offset(y: contentTop)

                if usesMeasuredTabBar {
                    HomeLifetimeStatsLayoutGuideLine(
                        label: "OLD ESTIMATE (\(Int(estimatedTabBarClearance))pt)",
                        color: .orange.opacity(0.65)
                    )
                    .offset(y: estimatedReserveTop)
                }

                HomeLifetimeStatsLayoutGuideLine(
                    label: "UITabBar TOP (\(Int(bottomSafeAreaInset))pt reserve)",
                    color: .orange
                )
                .offset(y: tabReserveTop)

                HomeLifetimeStatsLayoutGuideLine(
                    label: "PANEL BOTTOM",
                    color: .red
                )
                .offset(y: max(height - 2, 0))

                if bottomSafeAreaInset > 0 {
                    HomeLifetimeStatsLayoutGuideLabel(
                        text: usesMeasuredTabBar ? "MEASURED TAB BAR" : "FALLBACK TAB BAR",
                        color: .red
                    )
                    .offset(x: 4, y: tabReserveTop + 4)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .accessibilityIdentifier("Home.LifetimeStats.LayoutGuides.Panel")
        }
    }
}

/// In-content bands: top margin, tile stack, bottom margin (inside the content slot).
private struct HomeLifetimeStatsSectionLayoutGuides: View {
    let width: CGFloat
    let height: CGFloat
    let edgeInsets: (top: CGFloat, bottom: CGFloat)
    let statRowCount: Int
    let showsBuddyLeaderboard: Bool

    var body: some View {
        let spacing = HomeLifetimeStatsTilesLayout.gridSpacing
        let statRowHeight = HomeLifetimeStatsTilesLayout.statTileHeight
        let buddyHeight = HomeLifetimeStatsTilesLayout.buddyTileHeight
        let minContent = HomeLifetimeStatsTilesLayout.scrollContentHeight(
            statRowCount: statRowCount,
            showsBuddyLeaderboard: showsBuddyLeaderboard
        )

        let tilesTop = edgeInsets.top
        let row1Bottom = tilesTop + statRowHeight
        let row2Bottom = tilesTop + CGFloat(statRowCount) * statRowHeight
            + CGFloat(max(statRowCount - 1, 0)) * spacing
        let buddyTop = showsBuddyLeaderboard ? row2Bottom + spacing : row2Bottom
        let buddyBottom = showsBuddyLeaderboard ? buddyTop + buddyHeight : row2Bottom
        let tilesBottom = tilesTop + minContent

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.yellow.opacity(0.10))
                .frame(width: width, height: max(tilesTop, 0))

            if edgeInsets.bottom > 0.5 {
                Rectangle()
                    .fill(Color.yellow.opacity(0.10))
                    .frame(width: width, height: edgeInsets.bottom)
                    .offset(y: height - edgeInsets.bottom)
            }

            Rectangle()
                .strokeBorder(Color.green.opacity(0.85), lineWidth: 1.5)
                .frame(width: width, height: max(minContent, 0))
                .offset(y: tilesTop)

            if showsBuddyLeaderboard {
                Rectangle()
                    .fill(Color.purple.opacity(0.08))
                    .frame(width: width, height: buddyHeight)
                    .offset(y: buddyTop)
            }

            HomeLifetimeStatsLayoutGuideLine(label: "CONTENT TOP", color: .yellow)
            HomeLifetimeStatsLayoutGuideLine(label: "TOP MARGIN END / TILES TOP", color: .green)
                .offset(y: tilesTop)
            HomeLifetimeStatsLayoutGuideLine(label: "STAT ROW 1", color: .mint)
                .offset(y: row1Bottom)
            if statRowCount > 1 {
                HomeLifetimeStatsLayoutGuideLine(label: "STAT ROW 2", color: .mint)
                    .offset(y: row2Bottom)
            }
            if showsBuddyLeaderboard {
                HomeLifetimeStatsLayoutGuideLine(label: "BUDDY TOP", color: .purple)
                    .offset(y: buddyTop)
                HomeLifetimeStatsLayoutGuideLine(label: "BUDDY BOTTOM", color: .purple)
                    .offset(y: buddyBottom)
            }
            HomeLifetimeStatsLayoutGuideLine(label: "TILES BOTTOM", color: .green)
                .offset(y: tilesBottom)
            HomeLifetimeStatsLayoutGuideLine(label: "BOTTOM MARGIN END / TAB TOP", color: .yellow)
                .offset(y: max(height - edgeInsets.bottom - 2, 0))
            HomeLifetimeStatsLayoutGuideLine(label: "CONTENT SLOT BOTTOM", color: .yellow)
                .offset(y: max(height - 2, 0))

            HomeLifetimeStatsLayoutGuideLabel(
                text: "TOP MARGIN \(Int(edgeInsets.top))pt",
                color: .yellow
            )
            .offset(x: 4, y: 4)

            HomeLifetimeStatsLayoutGuideLabel(
                text: "BOTTOM MARGIN \(Int(edgeInsets.bottom))pt",
                color: .yellow
            )
            .offset(x: 4, y: max(height - edgeInsets.bottom - 18, 0))

            HomeLifetimeStatsLayoutGuideLabel(
                text: "TILE GAP \(Int(spacing))pt",
                color: .mint
            )
            .offset(x: 4, y: tilesTop + statRowHeight + 2)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .accessibilityIdentifier("Home.LifetimeStats.LayoutGuides.Section")
    }
}

private struct HomeLifetimeStatsLayoutGuideLine: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            HomeLifetimeStatsLayoutGuideLabel(text: label, color: color)
            Rectangle()
                .fill(color)
                .frame(height: 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeLifetimeStatsLayoutGuideLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.92))
            .foregroundStyle(.black)
    }
}

struct HomeLifetimeStatsSection: View {
    let stats: HomeLifetimeStats
    let buddyLeaderboard: [HomeBuddyLeaderboardEntry]
    let unitSystem: DiveDisplayUnitSystem
    let onOpenLeaderboard: (HomeLifetimeStatsLeaderboardKind) -> Void
    let onOpenBuddy: (UUID) -> Void

    private var showsBuddyLeaderboard: Bool {
        HomeBuddyLeaderboardPresentation.shouldShow(
            diveCount: stats.diveCount,
            entries: buddyLeaderboard
        )
    }

    var body: some View {
        let tiles = highlightTiles
        let statRowCount = HomeLifetimeStatsLayout.rowCount(tileCount: tiles.count)
        let statTileHeight = HomeLifetimeStatsTilesLayout.statTileHeight
        let buddyTileHeight = HomeLifetimeStatsTilesLayout.buddyTileHeight

        GeometryReader { proxy in
            let tileSpacing = HomeLifetimeStatsTilesLayout.gridSpacing
            let edgeInsets = HomeLifetimeStatsLayout.resolvedVerticalEdgeInsets(
                totalHeight: proxy.size.height,
                statRowCount: statRowCount,
                showsBuddyLeaderboard: showsBuddyLeaderboard
            )
            let columns = Array(
                repeating: GridItem(.flexible(), spacing: tileSpacing),
                count: HomeLifetimeStatsLayout.gridColumnCount
            )

            VStack(spacing: 0) {
                Color.clear
                    .frame(height: edgeInsets.top)
                    .accessibilityHidden(true)

                VStack(spacing: showsBuddyLeaderboard ? tileSpacing : 0) {
                    LazyVGrid(columns: columns, spacing: tileSpacing) {
                        ForEach(tiles) { tile in
                            HomeStatTile(
                                title: tile.title,
                                value: tile.value,
                                footnote: tile.footnote,
                                systemImage: tile.systemImage,
                                action: tile.action
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: statTileHeight)
                        }
                    }

                    if showsBuddyLeaderboard {
                        HomeBuddyLeaderboardTile(
                            entries: buddyLeaderboard,
                            onOpenBuddy: onOpenBuddy
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: buddyTileHeight)
                    }
                }

                Color.clear
                    .frame(height: edgeInsets.bottom)
                    .accessibilityHidden(true)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .overlay {
                if HomeSheetContainerDebug.showsLayoutGuides {
                    HomeLifetimeStatsSectionLayoutGuides(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        edgeInsets: edgeInsets,
                        statRowCount: statRowCount,
                        showsBuddyLeaderboard: showsBuddyLeaderboard
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .accessibilityIdentifier("Home.LifetimeStats")
    }

    private var highlightTiles: [HomeHighlightStatTile] {
        HomeLifetimeStatsPresentation.highlightStatTileDescriptors(
            stats: stats,
            unitSystem: unitSystem
        )
        .map { descriptor in
            HomeHighlightStatTile(
                id: descriptor.id,
                title: descriptor.title,
                value: descriptor.value,
                footnote: descriptor.footnote,
                systemImage: descriptor.systemImage,
                action: descriptor.leaderboardKind.map { kind in
                    { onOpenLeaderboard(kind) }
                }
            )
        }
    }
}

private struct HomeHighlightStatTile: Identifiable {
    let id: String
    let title: String
    let value: String
    let footnote: String
    let systemImage: String
    let action: (() -> Void)?
}

private struct HomeStatTile: View {
    let title: String
    let value: String
    let footnote: String
    let systemImage: String
    var action: (() -> Void)?

    private var showsFootnote: Bool {
        !footnote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    tileLabel
                }
                .buttonStyle(.plain)
            } else {
                tileLabel
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: HomeLifetimeStatsLayout.statTileHeight,
            maxHeight: HomeLifetimeStatsLayout.statTileHeight,
            alignment: .topLeading
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(action != nil ? .isButton : [])
        .accessibilityHint(action != nil ? "Opens top ten list" : "")
    }

    private var tileLabel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: HomeLifetimeStatsLayout.titleFontSize(), weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: HomeLifetimeStatsLayout.titleFontSize(), weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.mutedText)
                        .accessibilityHidden(true)
                }
            }

            Text(value)
                .font(.system(size: HomeLifetimeStatsLayout.valueFontSize(), weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Always reserve the footnote line so empty (—) and populated tiles share one height.
            Text(showsFootnote ? footnote : " ")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(showsFootnote ? 1 : 0)
                .accessibilityHidden(!showsFootnote)

            Spacer(minLength: 0)
        }
        .padding(HomeLifetimeStatsLayout.statTilePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appHighlightTileChrome()
    }

    private var accessibilityLabel: String {
        "\(title), \(value)\(showsFootnote ? ", \(footnote)" : "")"
    }
}

// MARK: - Buddy leaderboard

struct HomeBuddyLeaderboardTile: View {
    let entries: [HomeBuddyLeaderboardEntry]
    let onOpenBuddy: (UUID) -> Void

    private var displayEntries: [HomeBuddyLeaderboardEntry] {
        HomeBuddyLeaderboardPresentation.displayEntries(from: entries)
    }

    private var isEmpty: Bool {
        displayEntries.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "person.2.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .accessibilityHidden(true)
                Text("Top buddies")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                Spacer(minLength: 0)
            }

            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                if isEmpty {
                    ForEach(1 ... HomeBuddyLeaderboardPresentation.displayLimit, id: \.self) { rank in
                        HomeBuddyLeaderboardEmptySlot(rank: rank)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    ForEach(displayEntries) { entry in
                        HomeBuddyLeaderboardPodiumSlot(
                            entry: entry,
                            onOpen: { onOpenBuddy(entry.id) }
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .frame(minHeight: HomeBuddyLeaderboardLayout.podiumRowHeight)
        }
        .padding(HomeLifetimeStatsLayout.statTilePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appHighlightTileChrome()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Home.BuddyLeaderboard")
        .accessibilityLabel(leaderboardAccessibilityLabel)
    }

    private var leaderboardAccessibilityLabel: String {
        guard !isEmpty else {
            return HomeBuddyLeaderboardPresentation.emptyAccessibilityLabel
        }
        let summaries = displayEntries.map { entry in
            "\(DiveBuddyPresentation.firstName(from: entry.displayName)), \(HomeBuddyLeaderboardPresentation.diveCountLabel(count: entry.diveCount))"
        }
        return "Top buddies, " + summaries.joined(separator: "; ")
    }
}

private struct HomeBuddyLeaderboardEmptySlot: View {
    let rank: Int

    var body: some View {
        VStack(spacing: 4) {
            ProfileAvatarView(
                profilePhoto: nil,
                diameter: HomeBuddyLeaderboardLayout.avatarDiameter,
                iconFont: .caption,
                placeholderInitials: nil
            )
            .opacity(0.45)

            Text(HomeBuddyLeaderboardPresentation.emptySlotLabel)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppTheme.Colors.mutedText)
                .lineLimit(1)

            Text(HomeBuddyLeaderboardPresentation.emptySlotLabel)
                .font(.caption2)
                .foregroundStyle(AppTheme.Colors.mutedText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HomeBuddyLeaderboardPresentation.emptyFootnote)
        .accessibilityIdentifier("Home.BuddyLeaderboard.EmptySlot.\(rank)")
    }
}

private struct HomeBuddyLeaderboardPodiumSlot: View {
    let entry: HomeBuddyLeaderboardEntry
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 4) {
                ProfileAvatarView(
                    profilePhoto: entry.profilePhoto,
                    diameter: HomeBuddyLeaderboardLayout.avatarDiameter,
                    iconFont: .caption,
                    placeholderInitials: DiveBuddyPresentation.initials(from: entry.displayName)
                )

                Text(DiveBuddyPresentation.firstName(from: entry.displayName))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(HomeBuddyLeaderboardPresentation.diveCountLabel(count: entry.diveCount))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Colors.mutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(DiveBuddyPresentation.firstName(from: entry.displayName)), rank \(entry.rank), \(HomeBuddyLeaderboardPresentation.diveCountLabel(count: entry.diveCount))"
        )
        .accessibilityHint("Opens buddy details")
        .accessibilityIdentifier("Home.BuddyLeaderboard.Slot.\(entry.rank)")
    }
}

private struct HomeMediaCarouselTopSafeAreaBleedModifier: ViewModifier {
    let topSafeAreaInset: CGFloat
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .padding(.top, -topSafeAreaInset)
                .ignoresSafeArea(edges: .top)
        } else {
            content
        }
    }
}
