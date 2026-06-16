import SwiftUI

/// Full-bleed marine-life card over trip media — feature image, name, link to Field Guide overview.
struct TripDetailMediaMarineLifeOverlay: View {
    let taggedSpecies: [MarineLife]
    let previewSize: CGSize
    let cornerRadius: CGFloat
    let ownerProfileID: UUID?
    var featureImageHeight: CGFloat = TripDetailMediaGalleryPresentation.marineLifeOverlayFeatureImageHeight
    var featureImageMaxWidth: CGFloat = TripDetailMediaGalleryPresentation.marineLifeOverlayFeatureImageMaxWidth
    @Binding var selectedSpeciesUUID: String?
    var onOpenDive: (UUID) -> Void
    var onClose: () -> Void

    private var resolvedSelectedSpecies: MarineLife? {
        guard let resolvedUUID = DiveActivityMediaPresentation.resolvedTaggedSpeciesUUID(
            selectedUUID: selectedSpeciesUUID,
            taggedSpeciesUUIDs: taggedSpecies.map(\.uuid)
        ) else { return nil }
        return taggedSpecies.first(where: { $0.uuid == resolvedUUID })
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
                }

            VStack(spacing: AppTheme.Spacing.lg) {
                if taggedSpecies.count > 1 {
                    speciesSelector
                        .padding(.top, AppTheme.Spacing.lg + AppTheme.Spacing.md)
                } else {
                    Spacer(minLength: AppTheme.Spacing.lg)
                }

                if let resolvedSelectedSpecies {
                    speciesCard(for: resolvedSelectedSpecies)
                }

                Spacer(minLength: AppTheme.Spacing.lg)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .frame(width: previewSize.width, height: previewSize.height, alignment: .top)

            closeButton
                .padding(AppTheme.Spacing.md)
        }
        .frame(width: previewSize.width, height: previewSize.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("TripDetail.Media.MarineLifeOverlay")
    }

    private var speciesSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MarineLifeMediaTagPresentation.chipRowSpacing) {
                ForEach(taggedSpecies, id: \.uuid) { species in
                    Button {
                        selectedSpeciesUUID = species.uuid
                    } label: {
                        ActivityTagOvalChipLabel(
                            title: MarineLifeMediaTagPresentation.chipDisplayTitle(for: species.commonName),
                            isEmphasized: species.uuid == resolvedSelectedSpecies?.uuid
                        )
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("TripDetail.Media.MarineLifeOverlay.Species.\(species.uuid)")
                }
            }
        }
    }

    @ViewBuilder
    private func speciesCard(for species: MarineLife) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            featureImage(for: species)

            NavigationLink {
                FieldGuideMarineLifeDetailView(
                    species: species,
                    ownerProfileID: ownerProfileID,
                    onOpenDive: onOpenDive
                )
                .hidesBottomTabBarWhenPushed()
                .onAppear(perform: onClose)
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text(species.commonName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.accent)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .accessibilityIdentifier("TripDetail.Media.MarineLifeOverlay.ViewOverview")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func featureImage(for species: MarineLife) -> some View {
        FieldGuideMarineLifeCatalogImage(
            imageURLString: species.featureImageURL,
            bundleResourceName: species.featureImageResourceName,
            placement: .mediaSheetHero(height: featureImageHeight)
        )
        .frame(maxWidth: featureImageMaxWidth)
        .frame(maxWidth: .infinity)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close marine life overview")
        .accessibilityIdentifier("TripDetail.Media.MarineLifeOverlay.Close")
    }
}
