import SwiftUI

/// Compact fish-overlay on the Home media carousel — small feature image, centered common name, horizontal species paging.
struct HomeMediaCarouselMarineLifeOverlay: View {
    let taggedSpecies: [MarineLife]
    let previewSize: CGSize
    let cornerRadius: CGFloat
    let ownerProfileID: UUID?
    let closeTopInset: CGFloat
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
        speciesPager
            .frame(width: previewSize.width, height: previewSize.height)
            .background {
                Color.black.opacity(TripDetailMediaGalleryPresentation.marineLifeOverlayMediaScrimOpacity)
                    .ignoresSafeArea()
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(alignment: .topLeading) {
                closeButton
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.top, closeTopInset)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("Home.MediaCarousel.MarineLifeOverlay")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(.black.opacity(0.48))
                        .background {
                            Circle()
                                .fill(.ultraThinMaterial)
                        }
                        .clipShape(Circle())
                }
                .padding(AppTheme.Spacing.sm)
                .frame(minWidth: 48, minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close marine life overview")
        .accessibilityIdentifier("Home.MediaCarousel.MarineLifeOverlay.Close")
    }
}
