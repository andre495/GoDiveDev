import SwiftUI

// MARK: - Category hub (bento grid)

struct FieldGuideCatalogHubView: View {
    let summaries: [FieldGuideCatalogIndex.CategorySummary]
    let onSelectCategory: (String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.md),
        GridItem(.flexible(), spacing: AppTheme.Spacing.md),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                hubIntro
                LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
                    ForEach(summaries) { summary in
                        if let definition = FieldGuideTaxonomy.category(id: summary.categoryID) {
                            Button {
                                onSelectCategory(summary.categoryID)
                            } label: {
                                FieldGuideCategoryHubTile(
                                    definition: definition,
                                    speciesCount: summary.speciesCount,
                                    isFeatured: summary.categoryID == "fish"
                                )
                            }
                            .buttonStyle(.plain)
                            .gridCellColumns(summary.categoryID == "fish" ? 2 : 1)
                            .accessibilityIdentifier("FieldGuide.Hub.Category.\(summary.categoryID)")
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.lg)
        }
    }

    private var hubIntro: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Reef life atlas")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Browse Caribbean species by shape, phylum, and family — the way underwater field guides are organized.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppTheme.Spacing.sm)
    }
}

/// White line art on black (screen blend) over category gradients.
private struct FieldGuideCategoryBackgroundArt: View {
    let imageName: String
    var opacity: Double = 0.38
    var alignment: Alignment = .topTrailing
    var padding: CGFloat = 8
    /// ~30% smaller than full-bleed fit; anchored to the upper-trailing corner.
    var scale: CGFloat = 0.7
    /// Nudges silhouette toward the upper-right of hub tiles and category heroes.
    var rotationDegrees: Double = 10

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale, anchor: .topTrailing)
            .rotationEffect(.degrees(rotationDegrees), anchor: .topTrailing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .padding(padding)
            .opacity(opacity)
            .blendMode(.screen)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct FieldGuideCategoryHubTile: View {
    let definition: FieldGuideTaxonomy.Category
    let speciesCount: Int
    let isFeatured: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            FieldGuideCategoryAccent.gradientTop(definition.id),
                            FieldGuideCategoryAccent.gradientBottom(definition.id),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let heroImageName = definition.heroImageName, !heroImageName.isEmpty {
                FieldGuideCategoryBackgroundArt(
                    imageName: heroImageName,
                    opacity: isFeatured ? 0.42 : 0.36,
                    padding: AppTheme.Spacing.sm
                )
            } else {
                Image(systemName: definition.systemImage)
                    .font(.system(size: isFeatured ? 72 : 48, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.22))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(AppTheme.Spacing.md)
                    .offset(x: 8, y: -4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(definition.title)
                    .font(isFeatured ? .title3.weight(.bold) : .headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Text(definition.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(isFeatured ? 2 : 2)
                    .multilineTextAlignment(.leading)

                speciesBadge
            }
            .padding(AppTheme.Spacing.md)
        }
        .frame(minHeight: isFeatured ? 148 : 118)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(definition.title), \(speciesCount) catalog species")
        .accessibilityHint("Opens \(definition.title) groups")
    }

    @ViewBuilder
    private var speciesBadge: some View {
        Text(speciesCount == 0 ? "Explore" : "\(speciesCount) species")
            .font(.caption2.weight(.bold))
            .foregroundStyle(FieldGuideCategoryAccent.gradientTop(definition.id))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(.white.opacity(0.92))
            }
            .padding(.top, 2)
    }
}

// MARK: - Category detail (header + subcategory list)

struct FieldGuideCategoryDetailView: View {
    let categoryID: String
    let summary: FieldGuideCatalogIndex.CategorySummary
    let onSelectSubcategory: (String) -> Void

    private var definition: FieldGuideTaxonomy.Category? {
        FieldGuideTaxonomy.category(id: categoryID)
    }

    var body: some View {
        AppPage(
            title: definition?.title ?? "Category",
            showsBackButton: true,
            trailingContent: { EmptyView() }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    if let definition {
                        FieldGuideCategoryHeader(
                            definition: definition,
                            categoryID: categoryID,
                            speciesCount: summary.speciesCount
                        )

                        FieldGuideSubcategoryListSection(
                            subcategories: definition.subcategories,
                            counts: summary.subcategoryCounts,
                            categoryID: categoryID,
                            onSelect: onSelectSubcategory
                        )
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
        }
        .hidesBottomTabBarWhenPushed()
    }
}

/// Category hero image (placeholder until bundled art ships), title, and description.
struct FieldGuideCategoryHeader: View {
    let definition: FieldGuideTaxonomy.Category
    let categoryID: String
    let speciesCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            FieldGuideCategoryHeroImage(
                categoryID: categoryID,
                systemImage: definition.systemImage,
                heroImageName: definition.heroImageName
            )

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(definition.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(definition.description)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                speciesCountLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(definition.title). \(definition.description)")
    }

    @ViewBuilder
    private var speciesCountLabel: some View {
        if speciesCount > 0 {
            Text("\(speciesCount) species in catalog")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FieldGuideCategoryAccent.gradientTop(categoryID))
        }
    }
}

/// Wide hero slot — loads a future asset name or shows a gradient placeholder.
struct FieldGuideCategoryHeroImage: View {
    let categoryID: String
    let systemImage: String
    let heroImageName: String?

    private let heroHeight: CGFloat = 200

    var body: some View {
        ZStack {
            categoryGradient

            if let heroImageName, !heroImageName.isEmpty {
                FieldGuideCategoryBackgroundArt(
                    imageName: heroImageName,
                    opacity: 0.44,
                    padding: AppTheme.Spacing.sm
                )
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.28))
                    .offset(x: 48, y: -24)

                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: systemImage)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))

                    Text("Photo coming soon")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: heroHeight)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FieldGuideCategoryAccent.gradientTop(categoryID).opacity(0.2), lineWidth: 1)
        }
        .accessibilityLabel(
            heroImageName == nil ? "Category photo placeholder" : "Category illustration"
        )
    }

    private var categoryGradient: some View {
        LinearGradient(
            colors: [
                FieldGuideCategoryAccent.gradientTop(categoryID),
                FieldGuideCategoryAccent.gradientBottom(categoryID),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct FieldGuideSubcategoryListSection: View {
    let subcategories: [FieldGuideTaxonomy.Subcategory]
    let counts: [String: Int]
    let categoryID: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Groups")
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(subcategories) { subcategory in
                    Button {
                        onSelect(subcategory.id)
                    } label: {
                        FieldGuideSubcategoryRow(
                            subcategory: subcategory,
                            speciesCount: counts[subcategory.id, default: 0],
                            categoryID: categoryID
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("FieldGuide.Category.\(categoryID).Subcategory.\(subcategory.id)")
                }
            }
        }
    }
}

private struct FieldGuideSubcategoryRow: View {
    let subcategory: FieldGuideTaxonomy.Subcategory
    let speciesCount: Int
    let categoryID: String

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(FieldGuideCategoryAccent.gradientTop(categoryID).opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: subcategory.systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(FieldGuideCategoryAccent.gradientTop(categoryID))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(subcategory.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(subcategory.hint)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            VStack(alignment: .trailing, spacing: 4) {
                Text(speciesCount == 0 ? "—" : "\(speciesCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FieldGuideCategoryAccent.gradientTop(categoryID))
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FieldGuideCategoryAccent.gradientTop(categoryID).opacity(0.18), lineWidth: 1)
        }
    }
}

// MARK: - Subcategory species mosaic

struct FieldGuideSubcategorySpeciesView: View {
    let categoryID: String
    let subcategoryID: String
    let catalog: [MarineLifeCatalogSnapshot]
    let unitSystem: DiveDisplayUnitSystem
    let onSelectSpecies: (String) -> Void

    private var subcategory: FieldGuideTaxonomy.Subcategory? {
        FieldGuideTaxonomy.subcategory(categoryID: categoryID, subcategoryID: subcategoryID)
    }

    private var species: [MarineLifeCatalogSnapshot] {
        FieldGuideCatalogIndex.species(
            in: categoryID,
            subcategoryID: subcategoryID,
            catalog: catalog
        )
    }

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.md),
        GridItem(.flexible(), spacing: AppTheme.Spacing.md),
    ]

    var body: some View {
        AppPage(
            title: subcategory?.title ?? "Species",
            showsBackButton: true,
            trailingContent: { EmptyView() }
        ) {
            ScrollView {
                if species.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
                        ForEach(species, id: \.uuid) { entry in
                            Button {
                                onSelectSpecies(entry.uuid)
                            } label: {
                                FieldGuideSpeciesMosaicCard(
                                    entry: entry,
                                    unitSystem: unitSystem,
                                    accent: FieldGuideCategoryAccent.gradientTop(categoryID)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("FieldGuide.Species.\(entry.uuid)")
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                }
            }
        }
        .hidesBottomTabBarWhenPushed()
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: subcategory?.systemImage ?? "leaf")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
            Text("No species cataloged yet")
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("This group is ready for your sightings and future catalog updates.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.lg)
    }
}

private struct FieldGuideSpeciesMosaicCard: View {
    let entry: MarineLifeCatalogSnapshot
    let unitSystem: DiveDisplayUnitSystem
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.commonName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if !entry.scientificName.isEmpty {
                    Text(entry.scientificName)
                        .font(.caption2.italic())
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(1)
                }

                Text(FieldGuidePresentation.sizeDepthLine(for: entry, unitSystem: unitSystem))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .lineLimit(2)
            }
            .padding(AppTheme.Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.16), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var thumbnail: some View {
        let height: CGFloat = 108
        if let url = URL(string: entry.featureImageURL), !entry.featureImageURL.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    thumbnailPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
        } else {
            thumbnailPlaceholder
                .frame(height: height)
        }
    }

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(accent.opacity(0.12))
            .overlay {
                Image(systemName: "fish")
                    .font(.title2)
                    .foregroundStyle(accent.opacity(0.55))
            }
    }
}
