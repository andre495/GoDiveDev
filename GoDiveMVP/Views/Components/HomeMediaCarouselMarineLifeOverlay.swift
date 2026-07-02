import SwiftUI

/// Compact fish-overlay on the Home media carousel — small feature image, centered common name, horizontal species paging.
struct HomeMediaCarouselMarineLifeOverlay: View {
    let taggedSpecies: [MarineLife]
    let previewSize: CGSize
    let cornerRadius: CGFloat
    let ownerProfileID: UUID?
    let closeTopInset: CGFloat
    let speciesContentTopInset: CGFloat
    @Binding var selectedSpeciesUUID: String?
    var onOpenDive: (UUID) -> Void
    var onClose: () -> Void

    private var featureImageHeight: CGFloat {
        HomeMediaCarouselPresentation.marineLifeCarouselOverlayImageHeight(
            previewHeight: previewSize.height
        )
    }

    private var featureImageMaxWidth: CGFloat {
        HomeMediaCarouselPresentation.marineLifeCarouselOverlayImageMaxWidth(
            previewWidth: previewSize.width
        )
    }

    private var pagerHeight: CGFloat {
        HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageHeight(
            previewHeight: previewSize.height,
            speciesCount: taggedSpecies.count
        )
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

    var body: some View {
        ZStack(alignment: .topLeading) {
            fullMediaScrim

            speciesPager
                .padding(.top, speciesContentTopInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            closeButton
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, closeTopInset)
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
        .tabViewStyle(
            .page(indexDisplayMode: taggedSpecies.count > 1 ? .automatic : .never)
        )
        .frame(height: pagerHeight)
    }

    @ViewBuilder
    private func speciesPage(for species: MarineLife) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            FieldGuideMarineLifeCatalogImage(
                imageURLString: species.featureImageURL,
                bundleResourceName: species.featureImageResourceName,
                placement: .mediaSheetHero(
                    height: featureImageHeight,
                    cornerRadius: AppTheme.Spacing.sm
                )
            )
            .frame(width: featureImageMaxWidth, height: featureImageHeight)

            NavigationLink {
                FieldGuideMarineLifeDetailView(
                    species: species,
                    ownerProfileID: ownerProfileID,
                    onOpenDive: onOpenDive
                )
                .hidesBottomTabBarWhenPushed()
                .onAppear(perform: onClose)
            } label: {
                Text(species.commonName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: min(previewSize.width - AppTheme.Spacing.lg * 2, featureImageMaxWidth + 48))
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .accessibilityIdentifier("Home.MediaCarousel.MarineLifeOverlay.ViewOverview.\(species.uuid)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(species.commonName)
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
