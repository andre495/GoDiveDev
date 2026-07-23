import SwiftUI

/// Friend profile hero — remote Firebase media or shared-dive map (same band + map fit as other pushed heroes).
struct FriendProfileHeroHeaderView: View {
    let heroURL: URL?
    let mediaKind: GoDiveProfileHeroMediaKind?
    let mapPins: [TripDetailMapPin]
    let mapFitLayout: TripDetailMapFitLayout
    let isMapContentReady: Bool
    let shouldAutoPlayVideo: Bool
    @Binding var selectedMode: PushedDetailHeroHeaderView.Mode

    var body: some View {
        heroContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("FriendProfile.Hero")
            .onChange(of: mapPins.count) { _, count in
                let hasAssociatedMedia = heroURL != nil && mediaKind != nil
                guard PushedDetailHeroModePresentation.shouldFallBackFromMapToMedia(
                    mapPinCount: count,
                    currentMode: selectedMode,
                    isMapContentReady: isMapContentReady,
                    hasAssociatedMedia: hasAssociatedMedia
                ) else { return }
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

    @ViewBuilder
    private var mediaContent: some View {
        FriendProfileRemoteHeroView(
            heroURL: heroURL,
            mediaKind: mediaKind,
            shouldAutoPlayVideo: shouldAutoPlayVideo
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("FriendProfile.Hero.Media")
    }

    @ViewBuilder
    private var mapContent: some View {
        if isMapContentReady {
            TripDetailMapView(
                pins: mapPins,
                fitLayout: mapFitLayout,
                onSiteSelected: { _ in }
            )
            .accessibilityIdentifier("FriendProfile.Hero.Map")
        } else {
            BlueSheetDetailHeroLoadingBand(accessibilityLabel: "Loading map")
                .accessibilityIdentifier("FriendProfile.Hero.Map.Placeholder")
        }
    }
}
