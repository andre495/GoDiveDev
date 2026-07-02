import SwiftUI

/// Compact fish-overlay on the Home media carousel — tall fading feature image beside the common name, horizontal species paging.
struct HomeMediaCarouselMarineLifeOverlay: View {
    let taggedSpecies: [MarineLife]
    let previewSize: CGSize
    let cornerRadius: CGFloat
    let ownerProfileID: UUID?
    let closeTopInset: CGFloat
    let pageIndicatorBottomInset: CGFloat
    let heroBandHeight: CGFloat
    let topSafeAreaInset: CGFloat
    let panelOverlap: CGFloat
    @Binding var selectedSpeciesUUID: String?
    var onOpenDive: (UUID) -> Void
    var onClose: () -> Void

    private var featureImageMaxWidth: CGFloat {
        HomeMediaCarouselPresentation.marineLifeCarouselOverlayImageMaxWidth(
            previewWidth: previewSize.width
        )
    }

    private var speciesRowHeight: CGFloat {
        HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesRowHeight
    }

    private var sheetSeamYFromTop: CGFloat {
        HomeMediaCarouselPresentation.marineLifeCarouselOverlaySheetSeamYFromTop(
            heroBandHeight: heroBandHeight,
            topSafeAreaInset: topSafeAreaInset,
            panelOverlap: panelOverlap
        )
    }

    private var pageIndicatorTopInset: CGFloat {
        HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorTopInsetFromTop(
            sheetSeamYFromTop: sheetSeamYFromTop
        )
    }

    private var speciesNameTopInset: CGFloat {
        HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesNameTopInset(
            closeTopInset: closeTopInset
        )
    }

    private var featureImageColumnHeight: CGFloat {
        HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageColumnHeight(
            closeTopInset: closeTopInset,
            pageIndicatorTopInset: pageIndicatorTopInset,
            speciesRowHeight: speciesRowHeight
        )
    }

    private var speciesLeadingInset: CGFloat {
        HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesContentLeadingInset
    }

    private var speciesSelection: Binding<String> {
        Binding(
            get: {
                selectedSpeciesUUID
                    ?? taggedSpecies.first?.uuid
                    ?? ""
            },
            set: { selectedSpeciesUUID = $0 }
        )
    }

    private var speciesLabelMaxWidth: CGFloat {
        let horizontalChrome = speciesLeadingInset + AppTheme.Spacing.lg
        return max(
            120,
            previewSize.width
                - horizontalChrome
                - featureImageMaxWidth
                - AppTheme.Spacing.sm
        )
    }

    private var speciesDescriptionLineLimit: Int {
        HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesDescriptionLineLimit(
            speciesNameTopInset: speciesNameTopInset,
            pageIndicatorTopInset: pageIndicatorTopInset
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            fullMediaScrim

            speciesPager

            if taggedSpecies.count > 1 {
                speciesPageIndicator
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, pageIndicatorTopInset)
                    .zIndex(2)
            }

            closeButton
                .padding(.leading, speciesLeadingInset)
                .padding(.top, closeTopInset)
                .zIndex(3)
        }
        .frame(width: previewSize.width, height: previewSize.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Home.MediaCarousel.MarineLifeOverlay")
    }

    private var fullMediaScrim: some View {
        Rectangle()
            .fill(.black.opacity(HomeMediaCarouselPresentation.marineLifeCarouselOverlayMediaScrimOpacity))
            .background {
                Rectangle()
                    .fill(.thinMaterial)
            }
            .frame(width: previewSize.width, height: previewSize.height)
    }

    private var speciesPager: some View {
        TabView(selection: speciesSelection) {
            ForEach(taggedSpecies, id: \.uuid) { species in
                speciesPage(for: species)
                    .tag(species.uuid)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(width: previewSize.width, height: previewSize.height)
    }

    private var speciesPageIndicator: some View {
        let selectedUUID = speciesSelection.wrappedValue
        return HStack(spacing: HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorSpacing) {
            ForEach(taggedSpecies, id: \.uuid) { species in
                Circle()
                    .fill(
                        species.uuid == selectedUUID
                            ? Color.white
                            : Color.white.opacity(0.35)
                    )
                    .frame(
                        width: HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorDotSize,
                        height: HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorDotSize
                    )
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tagged species page indicator")
        .accessibilityIdentifier("Home.MediaCarousel.MarineLifeOverlay.PageIndicator")
    }

    @ViewBuilder
    private func speciesPage(for species: MarineLife) -> some View {
        ZStack(alignment: .topLeading) {
            featureImageColumn(for: species)
                .frame(width: featureImageMaxWidth, height: featureImageColumnHeight, alignment: .top)
                .padding(.leading, speciesLeadingInset)
                .padding(.top, closeTopInset)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            speciesNameRow(for: species)
        }
        .frame(width: previewSize.width, height: previewSize.height, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(species.commonName)
    }

    @ViewBuilder
    private func featureImageColumn(for species: MarineLife) -> some View {
        FieldGuideMarineLifeCatalogImage(
            imageURLString: species.featureImageURL,
            bundleResourceName: species.featureImageResourceName,
            placement: .mediaSheetHero(
                height: featureImageColumnHeight,
                cornerRadius: AppTheme.Spacing.sm
            )
        )
        .mask(marineLifeFeatureImageFadeMask)
    }

    private var marineLifeFeatureImageFadeMask: some View {
        let opaqueStop = HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageFadeOpaqueStop
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white, location: opaqueStop),
                .init(color: .white, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private func speciesNameRow(for species: MarineLife) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Color.clear
                .frame(width: featureImageMaxWidth, height: 1)
                .accessibilityHidden(true)

            NavigationLink {
                FieldGuideMarineLifeDetailView(
                    species: species,
                    ownerProfileID: ownerProfileID,
                    onOpenDive: onOpenDive
                )
                .hidesBottomTabBarWhenPushed()
                .onAppear(perform: onClose)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(species.commonName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: speciesLabelMaxWidth, alignment: .leading)

                    if let descriptionText = HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesDescriptionText(
                        aboutText: species.aboutText,
                        distinctiveFeatures: species.distinctiveFeatures
                    ) {
                        Text(descriptionText)
                            .font(.caption.italic())
                            .foregroundStyle(.white.opacity(0.88))
                            .multilineTextAlignment(.leading)
                            .lineLimit(speciesDescriptionLineLimit)
                            .minimumScaleFactor(0.9)
                            .frame(maxWidth: speciesLabelMaxWidth, alignment: .leading)
                    }
                }
                .frame(maxWidth: speciesLabelMaxWidth, alignment: .leading)
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .accessibilityIdentifier("Home.MediaCarousel.MarineLifeOverlay.ViewOverview.\(species.uuid)")
        }
        .padding(.top, speciesNameTopInset)
        .padding(.leading, speciesLeadingInset)
        .padding(.trailing, AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .appToolbarIconButtonLabel()
        }
        .appStandaloneIconButtonStyle()
        .foregroundStyle(.white)
        .accessibilityLabel("Close marine life overview")
        .accessibilityIdentifier("Home.MediaCarousel.MarineLifeOverlay.Close")
    }
}
