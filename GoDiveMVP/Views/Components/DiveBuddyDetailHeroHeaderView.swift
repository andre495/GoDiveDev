import SwiftUI

/// Buddy / trip hero — linked media or dive-site map, toggled from header chrome above the stats sheet overlap.
struct PushedDetailHeroHeaderView: View {
    struct Style: Sendable {
        let emptyPlaceholderSystemImage: String
        let emptyPlaceholderAccessibilityLabel: String
        let accessibilityPrefix: String

        nonisolated static let buddy = Style(
            emptyPlaceholderSystemImage: "person.2.fill",
            emptyPlaceholderAccessibilityLabel: "Buddy profile header",
            accessibilityPrefix: "DiveBuddyDetails.Hero"
        )

        nonisolated static let trip = Style(
            emptyPlaceholderSystemImage: "airplane",
            emptyPlaceholderAccessibilityLabel: "Trip header",
            accessibilityPrefix: "TripDetail.Hero"
        )

        nonisolated static let diveSite = Style(
            emptyPlaceholderSystemImage: "mappin.and.ellipse",
            emptyPlaceholderAccessibilityLabel: "Dive site header",
            accessibilityPrefix: "Explore.DiveSiteDetail.Hero"
        )

        nonisolated static let tag = Style(
            emptyPlaceholderSystemImage: "tag.fill",
            emptyPlaceholderAccessibilityLabel: "Tag header",
            accessibilityPrefix: "ActivityTagDetails.Hero"
        )

        nonisolated static let profile = Style(
            emptyPlaceholderSystemImage: "person.crop.circle.fill",
            emptyPlaceholderAccessibilityLabel: "Profile header",
            accessibilityPrefix: "Profile.Hero"
        )
    }

    enum Mode: String, CaseIterable, Hashable, Identifiable {
        case media
        case map

        var id: String { rawValue }

        var accessibilityLabel: String {
            switch self {
            case .media: "Tagged media"
            case .map: "Dive sites map"
            }
        }

        var shortTitle: String {
            switch self {
            case .media: "Media"
            case .map: "Map"
            }
        }

        var systemImage: String {
            switch self {
            case .media: "camera.fill"
            case .map: "map.fill"
            }
        }
    }

    let media: DiveMediaPhoto?
    let mapPins: [TripDetailMapPin]
    let mapFitLayout: TripDetailMapFitLayout
    let height: CGFloat
    /// **`true`** when media exists but the hero row has not resolved yet — show a muted loading band instead of the empty-state icon.
    var expectsTaggedMedia: Bool = false
    var isMapContentReady: Bool = true
    var shouldAutoPlaySelectedVideo: Bool = false
    var style: Style = .buddy
    var onSiteSelected: (UUID) -> Void
    @Binding var selectedMode: Mode

    init(
        media: DiveMediaPhoto?,
        mapPins: [TripDetailMapPin],
        mapFitLayout: TripDetailMapFitLayout,
        height: CGFloat,
        expectsTaggedMedia: Bool = false,
        isMapContentReady: Bool = true,
        shouldAutoPlaySelectedVideo: Bool = false,
        style: Style = .buddy,
        onSiteSelected: @escaping (UUID) -> Void,
        selectedMode: Binding<Mode> = .constant(.media)
    ) {
        self.media = media
        self.mapPins = mapPins
        self.mapFitLayout = mapFitLayout
        self.height = height
        self.expectsTaggedMedia = expectsTaggedMedia
        self.isMapContentReady = isMapContentReady
        self.shouldAutoPlaySelectedVideo = shouldAutoPlaySelectedVideo
        self.style = style
        self.onSiteSelected = onSiteSelected
        _selectedMode = selectedMode
    }

    var body: some View {
        heroContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(style.accessibilityPrefix)
            .onChange(of: mapPins.count) { oldCount, count in
                let willFallBack = PushedDetailHeroModePresentation.shouldFallBackFromMapToMedia(
                    mapPinCount: count,
                    currentMode: selectedMode,
                    isMapContentReady: isMapContentReady,
                    hasAssociatedMedia: media != nil || expectsTaggedMedia
                )
                BuddiesListNavigationDiagnostics.logHeroMapPinCountChange(
                    stylePrefix: style.accessibilityPrefix,
                    oldCount: oldCount,
                    newCount: count,
                    selectedMode: selectedMode.rawValue,
                    isMapContentReady: isMapContentReady,
                    hasAssociatedMedia: media != nil || expectsTaggedMedia,
                    willFallBackToMedia: willFallBack
                )
                guard willFallBack else { return }
                selectedMode = .media
            }
    }

    @ViewBuilder
    private var heroContent: some View {
        switch selectedMode {
        case .media:
            mediaContent
        case .map:
            mapContent
        }
    }

    private var mediaContent: some View {
        Group {
            if let media {
                DiveActivityMediaItemView(
                    media: media,
                    showsCaptureDateOverlay: false,
                    isVideoPlaybackActive: selectedMode == .media && shouldAutoPlaySelectedVideo,
                    loopsVideoPlayback: true
                )
                .id(media.id)
            } else if expectsTaggedMedia {
                BlueSheetDetailHeroLoadingBand(accessibilityLabel: "Loading tagged media")
            } else {
                BlueSheetDetailHeroPlaceholder(style: style)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("\(style.accessibilityPrefix).Media")
    }

    @ViewBuilder
    private var mapContent: some View {
        if isMapContentReady {
            TripDetailMapView(
                pins: mapPins,
                fitLayout: mapFitLayout,
                onSiteSelected: onSiteSelected
            )
            .accessibilityIdentifier("\(style.accessibilityPrefix).Map")
        } else {
            BlueSheetDetailHeroLoadingBand(accessibilityLabel: "Loading map")
                .accessibilityIdentifier("\(style.accessibilityPrefix).Map.Placeholder")
        }
    }
}

typealias DiveBuddyDetailHeroHeaderView = PushedDetailHeroHeaderView

/// Compact media / map toggle on pushed detail heroes (buddy, trip, species, dive site).
struct PushedDetailHeroModeToggle: View {
    @Binding var selectedMode: PushedDetailHeroHeaderView.Mode
    var accessibilityIdentifierPrefix: String = "DiveBuddyDetails.Hero.ModeToggle"

    var body: some View {
        HStack(spacing: PushedDetailHeroModeTogglePresentation.segmentSpacing) {
            ForEach(PushedDetailHeroHeaderView.Mode.allCases) { mode in
                segmentButton(for: mode)
            }
        }
        .padding(PushedDetailHeroModeTogglePresentation.shellPadding)
        .glassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: PushedDetailHeroModeTogglePresentation.shellCornerRadius)
        )
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifierPrefix)
    }

    private func segmentButton(for mode: PushedDetailHeroHeaderView.Mode) -> some View {
        let isSelected = selectedMode == mode

        return Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedMode = mode
            }
        } label: {
            Image(systemName: mode.systemImage)
                .font(.body.weight(.semibold))
                .frame(
                    width: PushedDetailHeroModeTogglePresentation.segmentSize,
                    height: PushedDetailHeroModeTogglePresentation.segmentSize
                )
                .contentShape(Rectangle())
                .foregroundStyle(isSelected ? AppTheme.Colors.tabSelected : AppTheme.Colors.tabUnselected)
                .background {
                    if isSelected {
                        RoundedRectangle(
                            cornerRadius: PushedDetailHeroModeTogglePresentation.segmentCornerRadius,
                            style: .continuous
                        )
                        .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
                    }
                }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(mode.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("\(accessibilityIdentifierPrefix).\(mode.rawValue)")
    }
}

typealias DiveBuddyDetailHeroModeToggle = PushedDetailHeroModeToggle
