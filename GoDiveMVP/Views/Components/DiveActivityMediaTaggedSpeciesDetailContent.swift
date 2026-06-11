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
        switch FieldGuideMarineLifeHeroPresentation.heroKind(
            featureModelResourceName: species.featureModelResourceName,
            featureImageResourceName: species.featureImageResourceName,
            featureImageURL: species.featureImageURL
        ) {
        case .model3D(let configuration):
            FieldGuideMarineLifeRealityHeroView(
                configuration: configuration,
                height: heroHeight
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Spacing.md, style: .continuous))
        case .bundledPhoto, .remoteImage:
            FieldGuideMarineLifeCatalogImage(
                imageURLString: species.featureImageURL,
                bundleResourceName: species.featureImageResourceName,
                placement: .mediaSheetHero(height: heroHeight)
            )
        case .placeholder:
            speciesHeroPlaceholder
                .frame(height: heroHeight)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Spacing.md, style: .continuous))
        }
    }

    private var speciesHeroPlaceholder: some View {
        Rectangle()
            .fill(AppTheme.Colors.tabUnselected.opacity(0.12))
            .overlay {
                Image(systemName: "fish")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
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
