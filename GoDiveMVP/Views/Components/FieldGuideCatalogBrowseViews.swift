import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Category hub (full-width rows — logbook dive tile spacing)

struct FieldGuideCatalogHubView: View, Equatable {
    let summaries: [FieldGuideCatalogIndex.CategorySummary]
    let topChromeInset: CGFloat
    let bottomChromeInset: CGFloat
    let statusBarSafeAreaTop: CGFloat
    let scrollToTopNonce: Int
    let onScrollOffsetChange: (CGFloat) -> Void
    let onSelectCategory: (FieldGuideCatalogIndex.CategorySummary) -> Void

    var body: some View {
        List {
            Color.clear
                .frame(height: topChromeInset)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityHidden(true)

            ForEach(summaries) { summary in
                if let definition = FieldGuideTaxonomy.category(id: summary.categoryID) {
                    Button {
                        onSelectCategory(summary)
                    } label: {
                        FieldGuideCategoryHubTile(
                            definition: definition,
                            speciesCount: summary.speciesCount
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(
                        EdgeInsets(
                            top: 0,
                            leading: AppTheme.Spacing.lg,
                            bottom: 0,
                            trailing: AppTheme.Spacing.lg
                        )
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("FieldGuide.Hub.Category.\(summary.categoryID)")
                }
            }

            Color.clear
                .frame(height: bottomChromeInset)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityHidden(true)
        }
        .listStyle(.plain)
        .listRowSpacing(FieldGuideHubTileLayout.listRowSpacing)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(edges: [.top, .bottom])
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { offset, _ in
            onScrollOffsetChange(offset)
        }
        .logbookListScrollToTopTrigger(nonce: scrollToTopNonce)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.summaries == rhs.summaries
            && lhs.topChromeInset == rhs.topChromeInset
            && lhs.bottomChromeInset == rhs.bottomChromeInset
            && lhs.statusBarSafeAreaTop == rhs.statusBarSafeAreaTop
            && lhs.scrollToTopNonce == rhs.scrollToTopNonce
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

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: FieldGuideHubTileLayout.tileCornerRadius, style: .continuous)
                .fill(categoryGradient)

            if let heroImageName = definition.heroImageName, !heroImageName.isEmpty {
                FieldGuideCategoryBackgroundArt(
                    imageName: heroImageName,
                    opacity: 0.36,
                    padding: AppTheme.Spacing.sm
                )
            } else {
                Image(systemName: definition.systemImage)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.22))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(FieldGuideHubTileLayout.tilePadding)
                    .offset(x: 8, y: -4)
            }

            HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(definition.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)

                    Text(definition.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        // `fixedSize(vertical:)` makes the text take the height it needs to wrap
                        // up to two lines instead of truncating to one line + ellipsis; a hard
                        // `maxHeight` cap clipped line two. `minHeight` still reserves the block.
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: FieldGuideHubTileLayout.subtitleTwoLineMinHeight,
                            alignment: .topLeading
                        )

                    speciesBadge
                }

                Spacer(minLength: 88)
            }
            .padding(FieldGuideHubTileLayout.tilePadding)
        }
        .frame(maxWidth: .infinity)
        .frame(height: FieldGuideHubTileLayout.tileHeight)
        .clipShape(
            RoundedRectangle(cornerRadius: FieldGuideHubTileLayout.tileCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: FieldGuideHubTileLayout.tileCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(definition.title), \(speciesCount) catalog species")
        .accessibilityHint("Opens \(definition.title) groups")
    }

    private var categoryGradient: LinearGradient {
        LinearGradient(
            colors: [
                FieldGuideCategoryAccent.gradientTop(definition.id),
                FieldGuideCategoryAccent.gradientBottom(definition.id),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var speciesBadge: some View {
        Text(speciesCount == 0 ? "Explore" : "\(speciesCount) species")
            .font(.caption2.weight(.bold))
            .foregroundStyle(FieldGuideCategoryAccent.gradientTop(definition.id))
            .padding(.horizontal, FieldGuideHubTileLayout.speciesBadgeHorizontalPadding)
            .padding(.vertical, FieldGuideHubTileLayout.speciesBadgeVerticalPadding)
            .background {
                Capsule().fill(.white)
            }
            .padding(.top, 2)
    }
}

/// Hub tile layout — full-width list rows aligned with **`LogbookActivityRowLayout`** spacing.
enum FieldGuideHubTileLayout: Sendable {
    nonisolated static let listRowSpacing: CGFloat = AppTheme.Spacing.sm
    /// Fits a title + fixed two-line subtitle + species pill with the same **`cardPadding`** (8 pt)
    /// breathing room the dive activity tile gets from its intrinsic height (previously 96 pt
    /// squeezed the content against the tile edges).
    nonisolated static let tileHeight: CGFloat = 108
    nonisolated static let tilePadding: CGFloat = LogbookActivityRowLayout.cardPadding
    nonisolated static let tileCornerRadius: CGFloat = LogbookActivityRowLayout.cardCornerRadius
    /// Species pill insets — match the dive activity tile's compact **`ActivityTagOvalChipLabel`** oval.
    nonisolated static let speciesBadgeHorizontalPadding: CGFloat = 10
    nonisolated static let speciesBadgeVerticalPadding: CGFloat = 4
    nonisolated static let hubTitleScrollFeather: CGFloat = 44

    nonisolated static func hubScrollScrimHeight(topChromeInset: CGFloat) -> CGFloat {
        topChromeInset + hubTitleScrollFeather
    }

    /// Fixed two-line **`.caption`** block for hub tile subtitles (blank second line when copy is short).
    nonisolated static var subtitleTwoLineMinHeight: CGFloat {
        #if canImport(UIKit)
        let font = UIFont.preferredFont(forTextStyle: .caption1)
        return ceil(font.lineHeight) * 2
        #else
        return 32
        #endif
    }

    nonisolated static func titleTwoLineMinHeight(isFeatured: Bool) -> CGFloat {
        #if canImport(UIKit)
        let style: UIFont.TextStyle = isFeatured ? .title3 : .headline
        let base = UIFont.preferredFont(forTextStyle: style)
        let font = isFeatured
            ? UIFont.boldSystemFont(ofSize: base.pointSize)
            : UIFont.systemFont(ofSize: base.pointSize, weight: .semibold)
        return ceil(font.lineHeight) * 2
        #else
        return isFeatured ? 50 : 44
        #endif
    }
}

// MARK: - Category detail (header + subcategory list)

struct FieldGuideCategoryDetailView: View {
    let categoryID: String
    let summary: FieldGuideCatalogIndex.CategorySummary
    let catalogSnapshots: [MarineLifeCatalogSnapshot]
    let subcategorySpeciesIndex: FieldGuideCatalogIndex.SubcategorySpeciesIndex
    let unitSystem: DiveDisplayUnitSystem
    let onSelectSubcategory: (String) -> Void
    let onSelectSpecies: (String) -> Void
    let onAddSpecies: () -> Void

    private var definition: FieldGuideTaxonomy.Category? {
        FieldGuideTaxonomy.category(id: categoryID)
    }

    var body: some View {
        FieldGuideCatalogBrowseListPage(
            title: definition?.title ?? summary.categoryID.capitalized,
            titleAccessibilityIdentifier: FieldGuideCategoryPresentation.browseTitleAccessibilityIdentifier(
                categoryID: categoryID
            ),
            accessibilityRootIdentifier: "FieldGuide.CategoryDetail.Root",
            listAccessibilityIdentifier: "FieldGuide.CategoryDetail.List",
            onAddSpecies: onAddSpecies
        ) {
            if let definition {
                FieldGuideCategoryDetailCopy(
                    definition: definition,
                    categoryID: categoryID,
                    speciesCount: summary.speciesCount
                )
            }
        } listRows: {
            if let definition {
                categoryListRows(definition: definition)
            }
        }
    }

    @ViewBuilder
    private func categoryListRows(definition: FieldGuideTaxonomy.Category) -> some View {
        let showsAllSpeciesFallback = FieldGuideSubcategorySearchPresentation.showsAllSpeciesFallback(
            subcategories: definition.subcategories,
            speciesCount: summary.speciesCount,
            query: ""
        )

        FieldGuideSubcategoryListSection(
            subcategories: definition.subcategories,
            counts: summary.subcategoryCounts,
            categoryID: categoryID,
            speciesCount: summary.speciesCount,
            subcategorySpeciesIndex: subcategorySpeciesIndex,
            showsAllSpeciesFallback: showsAllSpeciesFallback,
            onSelect: onSelectSubcategory
        )
    }
}

/// Description and species count for category browse list header (title lives in collapsible chrome).
struct FieldGuideCategoryDetailCopy: View {
    let definition: FieldGuideTaxonomy.Category
    let categoryID: String
    let speciesCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(definition.description)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            speciesCountLabel
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
    var totalHeight: CGFloat = 200
    var fullBleed: Bool = false

    var body: some View {
        ZStack {
            categoryGradient

            if let heroImageName, !heroImageName.isEmpty {
                FieldGuideCategoryBackgroundArt(
                    imageName: heroImageName,
                    opacity: fullBleed ? 0.5 : 0.44,
                    alignment: fullBleed ? .center : .topTrailing,
                    padding: fullBleed ? 0 : AppTheme.Spacing.sm,
                    scale: fullBleed ? 1.05 : 0.7,
                    rotationDegrees: fullBleed ? 0 : 10
                )
                .drawingGroup()
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
        .frame(height: totalHeight)
        .modifier(FieldGuideCategoryHeroChrome(categoryID: categoryID, fullBleed: fullBleed))
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

private struct FieldGuideCategoryHeroChrome: ViewModifier {
    let categoryID: String
    let fullBleed: Bool

    func body(content: Content) -> some View {
        if fullBleed {
            content.clipped()
        } else {
            content
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            FieldGuideCategoryAccent.gradientTop(categoryID).opacity(0.2),
                            lineWidth: 1
                        )
                }
        }
    }
}

struct FieldGuideSubcategoryListSection: View {
    let subcategories: [FieldGuideTaxonomy.Subcategory]
    let counts: [String: Int]
    let categoryID: String
    let speciesCount: Int
    let subcategorySpeciesIndex: FieldGuideCatalogIndex.SubcategorySpeciesIndex
    var showsAllSpeciesFallback: Bool = false
    let onSelect: (String) -> Void

    var body: some View {
        if showsAllSpeciesFallback {
            Button {
                onSelect("")
            } label: {
                FieldGuideSubcategoryFallbackRow(
                    title: "All species",
                    hint: "Browse every species in this category",
                    speciesCount: speciesCount,
                    categoryID: categoryID,
                    thumbnailSpecies: FieldGuideCatalogIndex.representativeSpecies(
                        categoryID: categoryID,
                        speciesIndex: subcategorySpeciesIndex
                    )
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("FieldGuide.Category.\(categoryID).Subcategory.all")
        }

        ForEach(subcategories) { subcategory in
            Button {
                onSelect(subcategory.id)
            } label: {
                FieldGuideSubcategoryRow(
                    subcategory: subcategory,
                    speciesCount: counts[subcategory.id, default: 0],
                    categoryID: categoryID,
                    thumbnailSpecies: FieldGuideCatalogIndex.representativeSpecies(
                        categoryID: categoryID,
                        subcategoryID: subcategory.id,
                        speciesIndex: subcategorySpeciesIndex
                    )
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("FieldGuide.Category.\(categoryID).Subcategory.\(subcategory.id)")
        }
    }
}

private struct FieldGuideSubcategoryFallbackRow: View {
    let title: String
    let hint: String
    let speciesCount: Int
    let categoryID: String
    let thumbnailSpecies: MarineLifeCatalogSnapshot?

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            FieldGuideSubcategoryRowThumbnail(
                categoryID: categoryID,
                systemImage: "list.bullet",
                species: thumbnailSpecies
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(speciesCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FieldGuideCategoryAccent.gradientTop(categoryID))
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
        }
        .padding(LogbookActivityRowLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
    }
}

private struct FieldGuideSubcategoryRow: View {
    let subcategory: FieldGuideTaxonomy.Subcategory
    let speciesCount: Int
    let categoryID: String
    let thumbnailSpecies: MarineLifeCatalogSnapshot?

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            FieldGuideSubcategoryRowThumbnail(
                categoryID: categoryID,
                systemImage: subcategory.systemImage,
                species: thumbnailSpecies
            )

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
        .padding(LogbookActivityRowLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius, style: .continuous)
                .stroke(FieldGuideCategoryAccent.gradientTop(categoryID).opacity(0.18), lineWidth: 1)
        }
    }
}

/// 44×44 subcategory list thumbnail — species photo when available, taxonomy icon otherwise.
private struct FieldGuideSubcategoryRowThumbnail: View {
    let categoryID: String
    let systemImage: String
    let species: MarineLifeCatalogSnapshot?

    private var thumbnailSize: CGFloat {
        FieldGuideCategoryPresentation.subcategoryRowThumbnailSize
    }

    var body: some View {
        Group {
            if let species,
               FieldGuideCatalogIndex.speciesHasCatalogImage(species) {
                FieldGuideMarineLifeCatalogImage(
                    imageURLString: species.featureImageURL,
                    bundleResourceName: species.featureImageResourceName,
                    placement: .mediaSheetHero(
                        height: thumbnailSize,
                        cornerRadius: 10
                    )
                )
            } else {
                placeholder
            }
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(FieldGuideCategoryAccent.gradientTop(categoryID).opacity(0.14))
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(FieldGuideCategoryAccent.gradientTop(categoryID))
        }
    }
}

// MARK: - Subcategory species mosaic

struct FieldGuideSubcategorySpeciesView: View {
    let payload: FieldGuideCatalogIndex.SubcategoryBrowsePayload
    let unitSystem: DiveDisplayUnitSystem
    let catalogSnapshots: [MarineLifeCatalogSnapshot]
    let onSelectSpecies: (String) -> Void
    let onAddSpecies: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.md),
        GridItem(.flexible(), spacing: AppTheme.Spacing.md),
    ]

    private var subcategoryDefinition: FieldGuideTaxonomy.Subcategory? {
        FieldGuideTaxonomy.subcategory(
            categoryID: payload.categoryID,
            subcategoryID: payload.subcategoryID
        )
    }

    var body: some View {
        FieldGuideCatalogBrowseListPage(
            title: payload.title,
            titleAccessibilityIdentifier: FieldGuideSubcategoryPresentation.browseTitleAccessibilityIdentifier(
                categoryID: payload.categoryID,
                subcategoryID: payload.subcategoryID
            ),
            accessibilityRootIdentifier: "FieldGuide.SubcategoryDetail.Root",
            listAccessibilityIdentifier: "FieldGuide.SubcategoryDetail.List",
            onAddSpecies: onAddSpecies
        ) {
            FieldGuideSubcategoryDetailCopy(
                title: payload.title,
                hint: subcategoryDefinition?.hint ?? "",
                speciesCount: payload.species.count,
                categoryID: payload.categoryID
            )
        } listRows: {
            subcategoryListRows
        }
    }

    @ViewBuilder
    private var subcategoryListRows: some View {
        if payload.species.isEmpty {
            emptyState
                .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        } else {
            LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
                ForEach(payload.species, id: \.uuid) { entry in
                    Button {
                        onSelectSpecies(entry.uuid)
                    } label: {
                        FieldGuideSpeciesMosaicCard(
                            entry: entry,
                            unitSystem: unitSystem,
                            accent: FieldGuideCategoryAccent.gradientTop(payload.categoryID)
                        )
                        .equatable()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("FieldGuide.Species.\(entry.uuid)")
                }
            }
            .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(
                systemName: FieldGuideTaxonomy.subcategory(
                    categoryID: payload.categoryID,
                    subcategoryID: payload.subcategoryID
                )?.systemImage ?? "leaf"
            )
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
        .padding(.vertical, AppTheme.Spacing.lg)
    }
}

/// Hint and species count for subcategory browse list header (title lives in collapsible chrome).
struct FieldGuideSubcategoryDetailCopy: View {
    let title: String
    let hint: String
    let speciesCount: Int
    let categoryID: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            if !hint.isEmpty {
                Text(hint)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            speciesCountLabel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private var speciesCountLabel: some View {
        if speciesCount > 0 {
            Text("\(speciesCount) species in catalog")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FieldGuideCategoryAccent.gradientTop(categoryID))
        }
    }

    private var accessibilitySummary: String {
        if hint.isEmpty {
            return title
        }
        return "\(title). \(hint)"
    }
}

/// Field Guide subcategory mosaic tile — reused on trip marine-life pager.
struct FieldGuideSpeciesMosaicCard: View, Equatable {
    let entry: MarineLifeCatalogSnapshot
    let unitSystem: DiveDisplayUnitSystem
    let accent: Color
    /// Optional extra line (e.g. trip sighting count).
    var supplementaryLine: String?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.entry == rhs.entry
            && lhs.unitSystem == rhs.unitSystem
            && lhs.accent == rhs.accent
            && lhs.supplementaryLine == rhs.supplementaryLine
    }

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
                    .lineLimit(supplementaryLine == nil ? 2 : 1)

                if let supplementaryLine, !supplementaryLine.isEmpty {
                    Text(supplementaryLine)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(
                height: FieldGuideMarineLifeImageLayout.mosaicLabelBlockHeight,
                alignment: .topLeading
            )
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

    private var thumbnail: some View {
        FieldGuideMarineLifeCatalogImage(
            imageURLString: entry.featureImageURL,
            bundleResourceName: entry.featureImageResourceName,
            placement: .mosaicTile(accent: accent)
        )
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
