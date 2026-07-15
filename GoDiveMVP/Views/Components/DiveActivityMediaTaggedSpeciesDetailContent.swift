import SwiftUI

/// Species hero + natural-history copy for the dive **Media** sheet at **large** detent.
struct DiveActivityMediaTaggedSpeciesDetailContent: View {
    let species: MarineLife
    var showsSpeciesHero: Bool = true
    var heroHeight: CGFloat = DiveActivityMediaPresentation.largeDetentSpeciesHeroHeight

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            if showsSpeciesHero {
                speciesHero
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(species.commonName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                if !species.scientificName.isEmpty {
                    Text(species.scientificName)
                        .font(.title3.italic())
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            ForEach(MarineLifeMediaTagPresentation.descriptionSections(for: species)) { section in
                descriptionBlock(title: section.title, body: section.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("DiveOverview.MediaTaggedSpeciesDetail.\(species.uuid)")
    }

    @ViewBuilder
    private var speciesHero: some View {
        switch FieldGuideMarineLifeHeroPresentation.mediaOverlayHeroKind(
            featureModelResourceName: species.featureModelResourceName,
            featureImageResourceName: species.featureImageResourceName,
            featureImageURL: species.featureImageURL,
            minSizeMeters: species.minSizeMeters,
            maxSizeMeters: species.maxSizeMeters
        ) {
        case .model3D(let configuration):
            FieldGuideMarineLifeRealityHeroView(configuration: configuration)
                .frame(height: heroHeight)
                .frame(maxWidth: .infinity, alignment: .center)
                .mask(speciesHeroTopFadeMask)
        case .bundledPhoto, .remoteImage:
            FieldGuideMarineLifeCatalogImage(
                imageURLString: species.featureImageURL,
                bundleResourceName: species.featureImageResourceName,
                placement: .mediaSheetHero(
                    height: heroHeight,
                    cornerRadius: 0,
                    alignment: .center,
                    contentMode: .fit
                )
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .mask(speciesHeroTopFadeMask)
        case .placeholder:
            speciesHeroPlaceholder
                .frame(height: heroHeight)
                .frame(maxWidth: .infinity, alignment: .center)
                .mask(speciesHeroTopFadeMask)
        }
    }

    private var speciesHeroTopFadeMask: some View {
        let opaqueStop = DiveActivityMediaPresentation.largeDetentSpeciesHeroTopFadeOpaqueStop
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

    private var speciesHeroPlaceholder: some View {
        Image(systemName: "fish")
            .font(.largeTitle)
            .foregroundStyle(AppTheme.Colors.tabUnselected)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func descriptionBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(body)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Horizontal chip picker when multiple species are tagged on one media item.
struct DiveActivityMediaTaggedSpeciesSelector: View {
    let species: [MarineLife]
    var media: DiveMediaPhoto?
    @Binding var selectedUUID: String?

    private var resolvedSelectedUUID: String? {
        guard !species.isEmpty else { return nil }
        if let selectedUUID, species.contains(where: { $0.uuid == selectedUUID }) {
            return selectedUUID
        }
        return species.first?.uuid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MarineLifeMediaTagPresentation.chipRowSpacing) {
                    ForEach(species, id: \.uuid) { item in
                        Button {
                            selectedUUID = item.uuid
                        } label: {
                            ActivityTagOvalChipLabel(
                                title: MarineLifeMediaTagPresentation.chipDisplayTitle(for: item.commonName),
                                isEmphasized: item.uuid == resolvedSelectedUUID,
                                showsFishialBadge: fishialBadge(for: item)
                            )
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("DiveOverview.MediaTaggedSpeciesChip.\(item.uuid)")
                    }
                }
            }
        }
        .accessibilityIdentifier("DiveOverview.MediaTaggedSpeciesSelector")
    }

    private func fishialBadge(for species: MarineLife) -> Bool {
        guard let media else { return false }
        return DiveActivityMediaPresentation.speciesWasFishialIdentified(species: species, on: media)
    }
}
