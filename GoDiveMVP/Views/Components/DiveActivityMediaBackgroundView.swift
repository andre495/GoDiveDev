import SwiftUI

/// Full-bleed **Media** tab hero — one photo or video at a time; horizontal paging.
struct DiveActivityMediaBackgroundView: View {
    private struct MediaSelectionSignature: Equatable {
        var count: Int
        var firstID: UUID?
        var lastID: UUID?
    }

    @Environment(\.displayScale) private var displayScale

    let mediaItems: [DiveMediaPhoto]
    @Binding var selectedMediaID: UUID?
    var timeZoneOffsetSeconds: Int?
    var mediaCaptureContextsByID: [UUID: DiveMediaCaptureContext] = [:]
    var sheetDetent: DiveActivityOverviewDetent = .medium
    var isMediaTabSelected: Bool = true
    var presentationEpoch: Int = 0
    /// Deep-link target (Home / logbook) — keeps the tapped photo selected while the pager hydrates.
    var deepLinkMediaID: UUID? = nil
    var onTagMarineLife: ((DiveMediaPhoto) -> Void)?
    var marineLifeSightings: [SightingInstance] = []
    /// Top padding so the marine-life fish control sits below the dive tab bar (see **`marineLifeTagButtonTopPadding`**).
    var marineLifeTagTopPadding: CGFloat = 0
    let bottomContentMargin: CGFloat
    /// Lifts the capture-date oval above the overview sheet when the hero is full-bleed.
    var captureOverlayBottomInset: CGFloat = 0

    @State private var pagerScrollReaffirmToken = 0

    private var showsMarineLifeTagButton: Bool {
        onTagMarineLife != nil
            && DiveActivityMediaPresentation.showsMarineLifeTagOnHero(for: sheetDetent)
    }

    private var showsBackgroundMedia: Bool {
        DiveActivityMediaPresentation.showsBackgroundPhotos(for: sheetDetent)
    }

    private var shouldPlayBackgroundVideo: Bool {
        DiveActivityMediaPresentation.shouldPlayBackgroundVideo(
            isMediaTabSelected: isMediaTabSelected,
            detent: sheetDetent
        )
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.screenBackgroundGradient
                .ignoresSafeArea()

            if showsBackgroundMedia {
                if mediaItems.isEmpty {
                    emptyState
                } else {
                    mediaPager
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(backgroundAccessibilityLabel)
        .accessibilityIdentifier("DiveActivity.MediaBackground")
        .onAppear { syncSelectionToMedia() }
        .onChange(of: mediaIDsSignature) { _, _ in
            syncSelectionToMedia()
        }
        .onChange(of: isMediaTabSelected) { _, isSelected in
            guard isSelected else { return }
            syncSelectionToMedia()
            reaffirmPagerSelectionIfNeeded(forceScrollReaffirm: true)
        }
        .onChange(of: presentationEpoch) { _, _ in
            reaffirmPagerSelectionIfNeeded(forceScrollReaffirm: true)
        }
        .onChange(of: mediaIDsSignature) { oldSignature, newSignature in
            guard isMediaTabSelected else { return }
            guard oldSignature.count == 0, newSignature.count > 0 else { return }
            syncSelectionToMedia()
            reaffirmPagerSelectionIfNeeded(forceScrollReaffirm: true)
        }
    }

    private var mediaIDsSignature: MediaSelectionSignature {
        MediaSelectionSignature(
            count: mediaItems.count,
            firstID: mediaItems.first?.id,
            lastID: mediaItems.last?.id
        )
    }

    private var mediaPager: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(mediaItems, id: \.id) { item in
                            DiveActivityMediaItemView(
                                media: item,
                                timeZoneOffsetSeconds: timeZoneOffsetSeconds,
                                captureContext: mediaCaptureContextsByID[item.id],
                                showsCaptureDateOverlay: DiveActivityMediaPresentation.showsCaptureDateOnHero(
                                    for: sheetDetent
                                ),
                                captureOverlayBottomInset: captureOverlayBottomInset,
                                showsMarineLifeTagButton: showsMarineLifeTagButton
                                    && selectedMediaID == item.id,
                                marineLifeTagIsActive: MarineLifeMediaTagPresentation.hasTaggedSpeciesOnMedia(
                                    mediaPhotoID: item.id,
                                    sightings: marineLifeSightings
                                ),
                                marineLifeTagTopInset: marineLifeTagTopPadding,
                                onTagMarineLife: showsMarineLifeTagButton
                                    && selectedMediaID == item.id
                                    ? { onTagMarineLife?(item) }
                                    : nil,
                            isVideoPlaybackActive: shouldPlayBackgroundVideo && selectedMediaID == item.id,
                            loopsVideoPlayback: shouldPlayBackgroundVideo
                        )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .id(item.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $selectedMediaID)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .ignoresSafeArea()
                .onAppear {
                    prefetchProgressiveNeighbors(screenPixelWidth: geometry.size.width * displayScale)
                }
                .onChange(of: selectedMediaID) { _, _ in
                    prefetchProgressiveNeighbors(screenPixelWidth: geometry.size.width * displayScale)
                }
                .onChange(of: pagerScrollReaffirmToken) { _, _ in
                    guard let selectedMediaID else { return }
                    proxy.scrollTo(selectedMediaID, anchor: .center)
                }
            }
        }
        .ignoresSafeArea()
        .padding(.bottom, bottomContentMargin)
        .accessibilityIdentifier("DiveActivity.MediaBackground.Pager")
    }

    private var emptyState: some View {
        Text(DiveActivityMediaPresentation.emptyStateMessage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tabUnselected)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, bottomContentMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("DiveActivity.MediaBackground.Empty")
    }

    private var backgroundAccessibilityLabel: String {
        guard showsBackgroundMedia else { return "Media sheet expanded" }
        if mediaItems.isEmpty {
            return DiveActivityMediaPresentation.emptyStateMessage
        }
        return "Dive media, \(mediaItems.count) items, swipe to change"
    }

    private func syncSelectionToMedia() {
        selectedMediaID = DiveActivityMediaPresentation.resolvedSelectedPhotoID(
            selectedID: selectedMediaID,
            in: mediaItems,
            preferredID: deepLinkMediaID
        )
    }

    private func reaffirmPagerSelectionIfNeeded(forceScrollReaffirm: Bool = false) {
        guard DiveActivityMediaActivation.shouldReaffirmPagerSelection(
            isMediaContextActive: isMediaTabSelected,
            mediaCount: mediaItems.count
        ) else { return }
        guard let target = DiveActivityMediaPresentation.resolvedSelectedPhotoID(
            selectedID: selectedMediaID,
            in: mediaItems,
            preferredID: deepLinkMediaID
        ) else { return }

        if forceScrollReaffirm, selectedMediaID == target {
            pagerScrollReaffirmToken &+= 1
        } else if selectedMediaID != target {
            selectedMediaID = target
        }
    }

    private func prefetchProgressiveNeighbors(screenPixelWidth: CGFloat) {
        DiveMediaProgressivePrefetch.warmNeighbors(
            mediaItems: mediaItems,
            selectedMediaID: selectedMediaID,
            screenPixelWidth: screenPixelWidth,
            isMediaTabSelected: isMediaTabSelected
        )
    }
}
