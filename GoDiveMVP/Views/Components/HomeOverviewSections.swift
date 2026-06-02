import SwiftData
import SwiftUI

// MARK: - Media carousel

enum HomeMediaCarouselLayout {
    /// Hero height = width × ratio + top safe inset + extension into the stats sheet overlap zone.
    static let heroHeightToWidthRatio: CGFloat = HomeOverviewLayout.heroHeightToWidthRatio

    /// Bottom inset for slide chrome — just above the stats sheet overlap.
    static var slideChromeBottomInset: CGFloat {
        HomeLifetimeStatsLayout.panelOverlap + AppTheme.Spacing.sm
    }

    /// Delay before mounting video playback after the pager selection changes (avoids mid-swipe swaps).
    static let playbackSettleMilliseconds: UInt64 = 320

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

struct HomeMediaCarouselLoadingPlaceholder: View {
    let containerWidth: CGFloat
    let topSafeAreaInset: CGFloat

    var body: some View {
        ZStack {
            AppTheme.Colors.surfaceElevated
            ProgressView()
                .tint(AppTheme.Colors.accent)
        }
        .frame(
            width: containerWidth,
            height: HomeMediaCarouselLayout.heroHeight(
                width: containerWidth,
                topSafeAreaInset: topSafeAreaInset
            )
        )
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("Home.MediaCarousel.Loading")
    }
}

/// Animated hero stand-in when the owner has dives but no Photos media for the daily carousel yet.
struct HomeMediaCarouselEmptyPlaceholder: View {
    let containerWidth: CGFloat
    let topSafeAreaInset: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var heroHeight: CGFloat {
        HomeMediaCarouselLayout.heroHeight(
            width: containerWidth,
            topSafeAreaInset: topSafeAreaInset
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.Colors.surfaceGradientTop.opacity(0.92),
                    AppTheme.Colors.accent.opacity(0.14),
                    AppTheme.Colors.surfaceGradientBottom.opacity(0.96),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ghostFrames
                .padding(.bottom, HomeLifetimeStatsLayout.panelOverlap * 0.35)

            VStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .symbolEffect(.pulse.byLayer, options: .repeating, isActive: !reduceMotion)
                    .accessibilityHidden(true)

                VStack(spacing: AppTheme.Spacing.sm) {
                    Text(HomeMediaCarouselEmptyPresentation.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(HomeMediaCarouselEmptyPresentation.message)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, HomeMediaCarouselLayout.slideChromeBottomInset)
        }
        .frame(width: containerWidth, height: heroHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(HomeMediaCarouselEmptyPresentation.title). \(HomeMediaCarouselEmptyPresentation.message)"
        )
        .accessibilityIdentifier("Home.MediaCarousel.Empty")
    }

    @ViewBuilder
    private var ghostFrames: some View {
        if reduceMotion {
            staticGhostFrames
        } else {
            animatedGhostFrames
        }
    }

    private var staticGhostFrames: some View {
        ZStack {
            ForEach(0 ..< HomeMediaCarouselEmptyPresentation.frameCount, id: \.self) { index in
                ghostFrame(index: index, verticalOffset: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var animatedGhostFrames: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0 ..< HomeMediaCarouselEmptyPresentation.frameCount, id: \.self) { index in
                    let phase = HomeMediaCarouselEmptyPresentation.framePhaseOffset(index: index)
                    let cycle = HomeMediaCarouselEmptyPresentation.animationCycleSeconds
                    let wave = sin((elapsed / cycle + phase) * 2 * .pi)
                    ghostFrame(
                        index: index,
                        verticalOffset: HomeMediaCarouselEmptyPresentation.frameOffsetAmplitude(index: index) * wave
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func ghostFrame(index: Int, verticalOffset: CGFloat) -> some View {
        let frameSize = ghostFrameSize(index: index)
        return RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(AppTheme.Colors.surfaceElevated.opacity(0.55))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppTheme.Colors.accent.opacity(0.22), lineWidth: 1)
            }
            .overlay {
                Image(systemName: index == 1 ? "video.fill" : "photo.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.Colors.accent.opacity(0.45))
            }
            .frame(width: frameSize.width, height: frameSize.height)
            .rotationEffect(.degrees(HomeMediaCarouselEmptyPresentation.frameRotationDegrees(index: index)))
            .offset(x: ghostFrameHorizontalOffset(index: index), y: verticalOffset + ghostFrameVerticalOffset(index: index))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
    }

    private func ghostFrameSize(index: Int) -> CGSize {
        switch index {
        case 0: CGSize(width: 108, height: 132)
        case 1: CGSize(width: 118, height: 142)
        default: CGSize(width: 104, height: 126)
        }
    }

    private func ghostFrameHorizontalOffset(index: Int) -> CGFloat {
        switch index {
        case 0: -containerWidth * 0.22
        case 1: 0
        default: containerWidth * 0.22
        }
    }

    private func ghostFrameVerticalOffset(index: Int) -> CGFloat {
        switch index {
        case 0: -12
        case 1: -28
        default: -8
        }
    }
}

struct HomeMediaCarouselSection: View {
    let highlights: [HomeMediaHighlight]
    let mediaByID: [UUID: DiveMediaPhoto]
    let divesByID: [UUID: DiveActivity]
    let containerWidth: CGFloat
    let topSafeAreaInset: CGFloat
    let headerOverlayHeight: CGFloat
    let onOpenDive: (UUID) -> Void
    let onOpenMedia: (UUID, UUID) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedIndex = 0
    @State private var playbackIndex = 0
    @State private var playbackSettleTask: Task<Void, Never>?
    @State private var isCarouselVisible = false
    @State private var marineLifeTagsMediaID: UUID?

    private var heroHeight: CGFloat {
        HomeMediaCarouselLayout.heroHeight(
            width: containerWidth,
            topSafeAreaInset: topSafeAreaInset
        )
    }

    private var isPlaybackAllowed: Bool {
        isCarouselVisible && scenePhase == .active
    }

    private var isAutoAdvanceEnabled: Bool {
        isPlaybackAllowed && HomeMediaCarouselPresentation.shouldAutoAdvance(slideCount: highlights.count)
    }

    private func isSlideActive(_ index: Int) -> Bool {
        isPlaybackAllowed && playbackIndex == index
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedIndex) {
                ForEach(Array(highlights.enumerated()), id: \.element.id) { index, highlight in
                    if let media = mediaByID[highlight.mediaID] {
                        HomeMediaCarouselPage(
                            highlight: highlight,
                            media: media,
                            pageWidth: containerWidth,
                            pageHeight: heroHeight,
                            isVideoPlaybackActive: isSlideActive(index),
                            isAutoAdvanceActive: isAutoAdvanceEnabled && isSlideActive(index),
                            onSlideFinished: advanceToNextSlide,
                            onOpenMedia: { onOpenMedia(highlight.diveActivityID, highlight.mediaID) },
                            onOpenDive: { onOpenDive(highlight.diveActivityID) },
                            onShowTaggedSpecies: { marineLifeTagsMediaID = highlight.mediaID }
                        )
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(width: containerWidth, height: heroHeight)
            .clipped()
            .onChange(of: selectedIndex) { _, newIndex in
                schedulePlaybackIndex(for: newIndex)
            }

            HomeMediaCarouselHeaderGradient(
                height: HomeMediaCarouselLayout.headerGradientHeight(
                    headerOverlayHeight: headerOverlayHeight,
                    topSafeAreaInset: topSafeAreaInset,
                    heroHeight: heroHeight
                )
            )
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, -topSafeAreaInset)
        .ignoresSafeArea(edges: .top)
        .accessibilityIdentifier("Home.MediaCarousel")
        .onAppear {
            isCarouselVisible = true
            playbackIndex = selectedIndex
        }
        .onDisappear {
            isCarouselVisible = false
            playbackSettleTask?.cancel()
        }
        .sheet(isPresented: marineLifeTagsSheetPresented) {
            if let context = marineLifeTagsSheetContext {
                DiveMarineLifeMediaTagsSheet(
                    media: context.media,
                    dive: context.dive,
                    captureContext: nil
                )
            }
        }
    }

    private var marineLifeTagsSheetPresented: Binding<Bool> {
        Binding(
            get: { marineLifeTagsMediaID != nil },
            set: { isPresented in
                if !isPresented {
                    marineLifeTagsMediaID = nil
                }
            }
        )
    }

    private var marineLifeTagsSheetContext: (media: DiveMediaPhoto, dive: DiveActivity)? {
        guard let mediaID = marineLifeTagsMediaID,
              let media = mediaByID[mediaID],
              let diveID = highlightDiveID(for: mediaID),
              let dive = divesByID[diveID] else {
            return nil
        }
        return (media, dive)
    }

    private func highlightDiveID(for mediaID: UUID) -> UUID? {
        highlights.first(where: { $0.mediaID == mediaID })?.diveActivityID
            ?? mediaByID[mediaID]?.diveActivityID
    }

    private func advanceToNextSlide() {
        guard HomeMediaCarouselPresentation.shouldAutoAdvance(slideCount: highlights.count) else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            selectedIndex = HomeMediaCarouselPresentation.nextIndex(
                after: selectedIndex,
                count: highlights.count
            )
        }
    }

    private func schedulePlaybackIndex(for index: Int) {
        playbackSettleTask?.cancel()
        playbackSettleTask = Task {
            let delay = HomeMediaCarouselLayout.playbackSettleMilliseconds
            if delay > 0 {
                try? await Task.sleep(for: .milliseconds(delay))
            }
            guard !Task.isCancelled else { return }
            playbackIndex = index
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
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    var isVideoPlaybackActive: Bool
    var isAutoAdvanceActive: Bool
    let onSlideFinished: () -> Void
    let onOpenMedia: () -> Void
    let onOpenDive: () -> Void
    let onShowTaggedSpecies: () -> Void

    var body: some View {
        HomeMediaCarouselMediaView(
            media: media,
            isVideoPlaybackActive: isVideoPlaybackActive,
            isAutoAdvanceActive: isAutoAdvanceActive,
            onSlideFinished: onSlideFinished
        )
        .frame(width: pageWidth, height: pageHeight)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenMedia)
        .overlay(alignment: .bottom) {
            HomeMediaCarouselSlideBottomChrome(
                highlight: highlight,
                onOpenDive: onOpenDive,
                onShowTaggedSpecies: onShowTaggedSpecies
            )
            .frame(width: pageWidth)
        }
        .frame(width: pageWidth, height: pageHeight)
        .accessibilityLabel("Dive media at \(highlight.siteDisplayName)")
    }
}

private struct HomeMediaCarouselSlideBottomChrome: View {
    let highlight: HomeMediaHighlight
    let onOpenDive: () -> Void
    let onShowTaggedSpecies: () -> Void

    private enum Layout {
        static let gradientHeight: CGFloat = 112
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.md) {
            HomeMediaCarouselDiveLinkButton(
                siteDisplayName: highlight.siteDisplayName,
                diveNumberLabel: highlight.diveNumberLabel,
                action: onOpenDive
            )

            Spacer(minLength: AppTheme.Spacing.sm)

            if highlight.hasTaggedSpecies {
                HomeMediaCarouselTaggedSpeciesButton(
                    taggedCount: highlight.taggedSpeciesCount,
                    action: onShowTaggedSpecies
                )
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

private struct HomeMediaCarouselDiveLinkButton: View {
    let siteDisplayName: String
    let diveNumberLabel: String
    let action: () -> Void

    private var title: String {
        let site = siteDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return site.isEmpty ? "New Dive" : site
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "book.closed.fill")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if diveNumberLabel != "-" {
                        Text(diveNumberLabel)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                    }
                }

            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background {
                Capsule()
                    .fill(.black.opacity(0.42))
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open dive at \(title)")
        .accessibilityIdentifier("Home.MediaCarousel.OpenDive")
    }
}

private struct HomeMediaCarouselTaggedSpeciesButton: View {
    let taggedCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
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

                if taggedCount > 1 {
                    Text("\(taggedCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppTheme.Colors.accentDeep))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(taggedCount > 1 ? "\(taggedCount) tagged species" : "Tagged marine life")
        .accessibilityHint("Shows species tagged on this photo")
        .accessibilityIdentifier("Home.MediaCarousel.TaggedSpecies")
    }
}

/// Home carousel media — reads session-cached hero frames synchronously; videos use warmed **`AVAsset`**s.
private struct HomeMediaCarouselMediaView: View {
    @Environment(\.modelContext) private var modelContext

    let media: DiveMediaPhoto
    var isVideoPlaybackActive: Bool
    var isAutoAdvanceActive: Bool
    let onSlideFinished: () -> Void

    #if canImport(UIKit)
    @State private var loadedImage: UIImage?
    #endif

    private var isVideo: Bool {
        media.resolvedMediaKind == .video
    }

    var body: some View {
        ZStack {
            photoContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(isVideo && isVideoPlaybackActive)

            if isVideo, isVideoPlaybackActive {
                DiveActivityVideoPlayerView(
                    source: media.videoPlaybackSource,
                    isPlaybackActive: true,
                    loopsPlayback: false,
                    onPlaybackFinished: isAutoAdvanceActive ? onSlideFinished : nil,
                    onAssetMissing: pruneIfAssetMissing
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(media.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: loadTaskID) {
            await loadHeroImageIfNeeded()
        }
        .task(id: photoAutoAdvanceTaskID) {
            await runPhotoAutoAdvanceIfNeeded()
        }
    }

    private var photoAutoAdvanceTaskID: String {
        "\(media.id.uuidString)-photo-auto-\(isAutoAdvanceActive)"
    }

    private func runPhotoAutoAdvanceIfNeeded() async {
        guard isAutoAdvanceActive, !isVideo else { return }
        let seconds = HomeMediaCarouselPresentation.photoDisplaySeconds
        try? await Task.sleep(for: .seconds(seconds))
        guard !Task.isCancelled, isAutoAdvanceActive else { return }
        onSlideFinished()
    }

    private var loadTaskID: String {
        "\(media.id.uuidString)-\(media.resolvedMediaKind.rawValue)"
    }

    @ViewBuilder
    private var photoContent: some View {
        #if canImport(UIKit)
        if let displayImage = sessionCachedImage ?? loadedImage {
            Image(uiImage: displayImage)
                .resizable()
                .scaledToFill()
                .accessibilityLabel("Dive photo")
        } else {
            heroPlaceholder
        }
        #else
        heroPlaceholder
        #endif
    }

    #if canImport(UIKit)
    private var sessionCachedImage: UIImage? {
        guard let identifier = media.libraryAssetLocalIdentifier else { return nil }
        return HomeMediaHighlightSessionCache.shared.bestCachedImage(localIdentifier: identifier)
    }
    #endif

    private var heroPlaceholder: some View {
        ZStack {
            AppTheme.Colors.surfaceMuted.opacity(0.5)
            ProgressView()
                .tint(AppTheme.Colors.accent)
        }
    }

    #if canImport(UIKit)
    private func loadHeroImageIfNeeded() async {
        if sessionCachedImage != nil {
            loadedImage = sessionCachedImage
            return
        }
        guard let identifier = media.libraryAssetLocalIdentifier else {
            loadedImage = nil
            return
        }
        let edge = HomeMediaHighlightWarmup.preloadImageEdge
        let size = CGSize(width: edge, height: edge)
        let image = await DiveMediaReferenceLoader.image(
            localIdentifier: identifier,
            targetSize: size
        )
        if image == nil {
            DiveMediaReferencePruning.pruneIfAssetMissing(media, modelContext: modelContext)
        }
        loadedImage = image
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
    static let gridSpacing = AppTheme.Spacing.md
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
    /// Breathing room between carousel bottom and stat tiles when the sheet overlaps the hero.
    static let panelTopContentPaddingWhenOverlapping: CGFloat = AppTheme.Spacing.lg + AppTheme.Spacing.sm

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
}

/// Sheet-style chrome for Home lifetime stats — rounded top, opaque fill, optional hero overlap.
struct HomeLifetimeStatsPanel<Content: View>: View {
    var overlapsMedia: Bool
    /// Keeps tiles above the tab bar while the panel fill extends to the viewport bottom.
    var bottomSafeAreaInset: CGFloat = 0
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(
                .top,
                overlapsMedia
                    ? HomeLifetimeStatsLayout.panelTopContentPaddingWhenOverlapping
                    : HomeLifetimeStatsLayout.panelTopContentPadding
            )
            .padding(.bottom, AppTheme.Spacing.sm + bottomSafeAreaInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                HomeLifetimeStatsPanelBackground()
            }
            .clipShape(panelShape)
            .shadow(
                color: .black.opacity(overlapsMedia ? 0.14 : 0.08),
                radius: overlapsMedia ? 16 : 8,
                y: overlapsMedia ? -6 : -2
            )
            .accessibilityIdentifier("Home.LifetimeStats.Panel")
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

private struct HomeLifetimeStatsPanelBackground: View {
    var body: some View {
        ZStack {
            AppTheme.Colors.surfaceElevated
            LinearGradient(
                colors: [
                    AppTheme.Colors.surfaceGradientTop.opacity(0.96),
                    AppTheme.Colors.surfaceGradientBottom,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

struct HomeLifetimeStatsSection: View {
    let stats: HomeLifetimeStats
    let buddyLeaderboard: [HomeBuddyLeaderboardEntry]
    let unitSystem: DiveDisplayUnitSystem
    let onOpenDive: (UUID) -> Void
    let onOpenSite: (UUID) -> Void
    let onOpenSpecies: (String) -> Void
    let onOpenBuddy: (UUID) -> Void

    private var showsBuddyLeaderboard: Bool {
        HomeBuddyLeaderboardPresentation.shouldShow(
            diveCount: stats.diveCount,
            entries: buddyLeaderboard
        )
    }

    var body: some View {
        let tiles = highlightTiles

        VStack(alignment: .leading, spacing: HomeLifetimeStatsLayout.gridSpacing) {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: HomeLifetimeStatsLayout.gridSpacing),
                    count: HomeLifetimeStatsLayout.gridColumnCount
                ),
                spacing: HomeLifetimeStatsLayout.gridSpacing
            ) {
                ForEach(tiles) { tile in
                    HomeStatTile(
                        title: tile.title,
                        value: tile.value,
                        footnote: tile.footnote,
                        systemImage: tile.systemImage,
                        action: tile.action
                    )
                }
            }
            .frame(height: HomeLifetimeStatsLayout.gridHeight(tileCount: tiles.count))

            if showsBuddyLeaderboard {
                HomeBuddyLeaderboardTile(
                    entries: buddyLeaderboard,
                    onOpenBuddy: onOpenBuddy
                )
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("Home.LifetimeStats")
    }

    private var highlightTiles: [HomeHighlightStatTile] {
        var tiles: [HomeHighlightStatTile] = []

        if let deepest = stats.deepestDive, let depth = stats.deepestMaxDepthMeters {
            tiles.append(
                HomeHighlightStatTile(
                    id: "deepest",
                    title: "Deepest",
                    value: formattedDepth(depth),
                    footnote: deepest.siteDisplayName,
                    systemImage: "arrow.down.circle.fill",
                    action: { onOpenDive(deepest.id) }
                )
            )
        }

        if let longest = stats.longestDive, let minutes = stats.longestDurationMinutes {
            tiles.append(
                HomeHighlightStatTile(
                    id: "longest",
                    title: "Longest",
                    value: HomeLifetimeStatsPresentation.formattedDuration(minutes: minutes),
                    footnote: longest.siteDisplayName,
                    systemImage: "clock.fill",
                    action: { onOpenDive(longest.id) }
                )
            )
        }

        if let site = stats.mostVisitedSite {
            tiles.append(
                HomeHighlightStatTile(
                    id: "top-site",
                    title: "Top site",
                    value: site.name,
                    footnote: HomeLifetimeStatsPresentation.siteVisitLabel(count: site.visitCount),
                    systemImage: "mappin.circle.fill",
                    action: site.id.map { siteID in { onOpenSite(siteID) } }
                )
            )
        }

        if let species = stats.topSpecies {
            tiles.append(
                HomeHighlightStatTile(
                    id: "top-species",
                    title: "Top species",
                    value: species.commonName,
                    footnote: HomeLifetimeStatsPresentation.sightingCountLabel(count: species.sightingCount),
                    systemImage: "fish.fill",
                    action: { onOpenSpecies(species.marineLifeUUID) }
                )
            )
        } else {
            tiles.append(
                HomeHighlightStatTile(
                    id: "top-species",
                    title: "Top species",
                    value: HomeLifetimeStatsPresentation.topSpeciesEmptyValue,
                    footnote: HomeLifetimeStatsPresentation.topSpeciesEmptyFootnote,
                    systemImage: "fish.fill",
                    action: nil
                )
            )
        }

        return tiles
    }

    private func formattedDepth(_ meters: Double?) -> String {
        guard let meters else { return "—" }
        return DiveQuantityFormatting.depth(meters: meters, system: unitSystem)
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
                    tileContent
                }
                .buttonStyle(.plain)
            } else {
                tileContent
            }
        }
    }

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: 6) {
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

            if showsFootnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.mutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(HomeLifetimeStatsLayout.statTilePadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: HomeLifetimeStatsLayout.statTileHeight, alignment: .topLeading)
        .homeHighlightTileChrome()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        "\(title), \(value)\(showsFootnote ? ", \(footnote)" : "")"
    }
}

private struct HomeHighlightTileChrome: View {
    var body: some View {
        RoundedRectangle(cornerRadius: HomeLifetimeStatsLayout.statTileCornerRadius, style: .continuous)
            .fill(AppTheme.Colors.surfaceMuted.opacity(0.55))
            .overlay {
                RoundedRectangle(cornerRadius: HomeLifetimeStatsLayout.statTileCornerRadius, style: .continuous)
                    .stroke(AppTheme.Colors.tabUnselected.opacity(0.14), lineWidth: 1)
            }
    }
}

private extension View {
    func homeHighlightTileChrome() -> some View {
        background {
            HomeHighlightTileChrome()
        }
    }
}

// MARK: - Buddy leaderboard

struct HomeBuddyLeaderboardTile: View {
    let entries: [HomeBuddyLeaderboardEntry]
    let onOpenBuddy: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "person.2.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .accessibilityHidden(true)
                Text("Top buddies")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                Spacer(minLength: 0)
            }

            HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                ForEach(entries) { entry in
                    HomeBuddyLeaderboardPodiumSlot(
                        entry: entry,
                        onOpen: { onOpenBuddy(entry.id) }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: HomeBuddyLeaderboardLayout.podiumRowHeight)
        }
        .padding(HomeLifetimeStatsLayout.statTilePadding)
        .frame(height: HomeBuddyLeaderboardLayout.estimatedTileHeight, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .homeHighlightTileChrome()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Home.BuddyLeaderboard")
        .accessibilityLabel(leaderboardAccessibilityLabel)
    }

    private var leaderboardAccessibilityLabel: String {
        let summaries = entries.map { entry in
            "\(DiveBuddyPresentation.firstName(from: entry.displayName)), \(HomeBuddyLeaderboardPresentation.diveCountLabel(count: entry.diveCount))"
        }
        return "Top buddies, " + summaries.joined(separator: "; ")
    }
}

private struct HomeBuddyLeaderboardPodiumSlot: View {
    let entry: HomeBuddyLeaderboardEntry
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: AppTheme.Spacing.sm) {
                ProfileAvatarView(
                    profilePhoto: entry.profilePhoto,
                    diameter: HomeBuddyLeaderboardLayout.avatarDiameter,
                    iconFont: .callout
                )

                Text(DiveBuddyPresentation.firstName(from: entry.displayName))
                    .font(.caption.weight(.medium))
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
