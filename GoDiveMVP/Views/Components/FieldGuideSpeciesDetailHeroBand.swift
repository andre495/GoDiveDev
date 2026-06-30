import SwiftUI

/// Species detail hero — tagged media, catalog image / 3D, or dive-site map behind one band contract.
struct FieldGuideSpeciesDetailHeroBand: View {
    let bandContentHeight: CGFloat
    let mapFitLayout: TripDetailMapFitLayout
    let heroMode: PushedDetailHeroHeaderView.Mode
    let mediaSource: FieldGuideSpeciesHeroMediaSource
    let heroTaggedMedia: DiveMediaPhoto?
    let taggedMediaItems: [DiveMediaPhoto]
    let catalogHeroAvailability: FieldGuideSpeciesCatalogHeroAvailability
    let catalogHeroDisplay: FieldGuideSpeciesCatalogHeroDisplay
    let featureModelResourceName: String
    let featureImageResourceName: String
    let featureImageURL: String
    let mapPins: [TripDetailMapPin]
    let isVideoPlaybackActive: Bool
    let onCatalogHeroTap: () -> Void
    let onSiteSelected: (UUID) -> Void

    var body: some View {
        BlueSheetDetailHeroBandFill(accessibilityIdentifier: "FieldGuide.SpeciesDetail.Hero") {
            Group {
                switch heroMode {
                case .media:
                    mediaHeroContent
                case .map:
                    mapHeroContent
                }
            }
        }
    }

    @ViewBuilder
    private var mediaHeroContent: some View {
        switch mediaSource {
        case .taggedUserMedia:
            taggedUserMediaHero
        case .catalogReference:
            catalogHeroContent
        }
    }

    @ViewBuilder
    private var taggedUserMediaHero: some View {
        Group {
            if let media = heroTaggedMedia {
                DiveActivityMediaItemView(
                    media: media,
                    showsCaptureDateOverlay: false,
                    isVideoPlaybackActive: isVideoPlaybackActive,
                    loopsVideoPlayback: true
                )
                .id(media.id)
            } else if !taggedMediaItems.isEmpty {
                BlueSheetDetailHeroLoadingBand(accessibilityLabel: "Loading tagged media")
            } else {
                catalogHeroContent
            }
        }
        .accessibilityIdentifier("FieldGuide.SpeciesDetail.Hero.TaggedMedia")
    }

    @ViewBuilder
    private var catalogHeroContent: some View {
        Group {
            switch catalogHeroDisplay {
            case .model3D:
                FieldGuideMarineLifeRealityHeroView(
                    configuration: FieldGuideMarineLifeHeroPresentation.sceneConfiguration(
                        forModelResourceName: featureModelResourceName
                    ),
                    height: bandContentHeight
                )
            case .image:
                FieldGuideMarineLifeCatalogImage(
                    imageURLString: featureImageURL,
                    bundleResourceName: featureImageResourceName,
                    placement: .detailHero(totalHeight: bandContentHeight)
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onCatalogHeroTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            FieldGuideSpeciesHeroPresentation.catalogHeroHeaderAccessibilityLabel(
                display: catalogHeroDisplay,
                supportsToggle: catalogHeroAvailability.supportsHeaderToggle
            )
        )
        .accessibilityAddTraits(catalogHeroAvailability.supportsHeaderToggle ? .isButton : [])
        .accessibilityIdentifier("FieldGuide.SpeciesDetail.Hero.Catalog")
    }

    @ViewBuilder
    private var mapHeroContent: some View {
        TripDetailMapView(
            pins: mapPins,
            fitLayout: mapFitLayout,
            onSiteSelected: onSiteSelected
        )
        .accessibilityIdentifier("FieldGuide.SpeciesDetail.Hero.Map")
    }
}
