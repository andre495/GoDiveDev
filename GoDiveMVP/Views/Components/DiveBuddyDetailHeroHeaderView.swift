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
            .onChange(of: mapPins.count) { _, count in
                if count == 0, selectedMode == .map {
                    selectedMode = .media
                }
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
                heroLoadingPlaceholder
            } else {
                heroPlaceholder
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
            AppTheme.Colors.surfaceMuted.opacity(0.35)
                .accessibilityIdentifier("\(style.accessibilityPrefix).Map.Placeholder")
        }
    }

    private var heroPlaceholder: some View {
        Rectangle()
            .fill(AppTheme.Colors.tabUnselected.opacity(0.12))
            .overlay {
                Image(systemName: style.emptyPlaceholderSystemImage)
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
            .accessibilityLabel(style.emptyPlaceholderAccessibilityLabel)
    }

    private var heroLoadingPlaceholder: some View {
        AppTheme.Colors.surfaceMuted.opacity(0.35)
            .accessibilityLabel("Loading tagged media")
    }
}

typealias DiveBuddyDetailHeroHeaderView = PushedDetailHeroHeaderView

/// Media / map segmented control — matches **`ExploreSiteScopeToggle`** chrome on pushed detail heroes.
struct PushedDetailHeroModeToggle: View {
    @Binding var selectedMode: PushedDetailHeroHeaderView.Mode
    var accessibilityIdentifierPrefix: String = "DiveBuddyDetails.Hero.ModeToggle"

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PushedDetailHeroHeaderView.Mode.allCases) { mode in
                Button {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        selectedMode = mode
                    }
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.caption.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(
                            selectedMode == mode
                                ? AppTheme.Colors.accent
                                : AppTheme.Colors.tabUnselected
                        )
                        .background {
                            if selectedMode == mode {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(AppTheme.Colors.surfaceElevated)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.accessibilityLabel)
                .accessibilityAddTraits(selectedMode == mode ? .isSelected : [])
                .accessibilityIdentifier("\(accessibilityIdentifierPrefix).\(mode.rawValue)")
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.tabUnselected.opacity(0.12))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Hero view")
        .accessibilityIdentifier(accessibilityIdentifierPrefix)
    }
}

typealias DiveBuddyDetailHeroModeToggle = PushedDetailHeroModeToggle
