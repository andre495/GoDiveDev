import SwiftUI

/// Species hero + natural-history copy for the dive **Media** sheet at **large** detent.
struct DiveActivityMediaTaggedSpeciesDetailContent: View {
    let species: MarineLife
    let heroHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            speciesHero

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
            featureImageURL: species.featureImageURL
        ) {
        case .model3D(let configuration):
            FieldGuideMarineLifeRealityHeroView(
                configuration: configuration,
                height: heroHeight
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Spacing.md, style: .continuous))
        case .remoteImage(let url):
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    speciesHeroPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: heroHeight)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Spacing.md, style: .continuous))
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
            Text(MarineLifeMediaTagPresentation.sectionTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(species, id: \.uuid) { item in
                        Button {
                            selectedUUID = item.uuid
                        } label: {
                            ActivityTagOvalChipLabel(
                                title: item.commonName,
                                isEmphasized: item.uuid == resolvedSelectedUUID
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("DiveOverview.MediaTaggedSpeciesChip.\(item.uuid)")
                    }
                }
            }
        }
        .accessibilityIdentifier("DiveOverview.MediaTaggedSpeciesSelector")
    }
}
