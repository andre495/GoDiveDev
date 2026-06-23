import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Category hub (full-width rows — logbook dive tile spacing)

struct FieldGuideCatalogHubView: View, Equatable {
    let summaries: [FieldGuideCatalogIndex.CategorySummary]
    let topChromeInset: CGFloat
    let statusBarSafeAreaTop: CGFloat
    let onSelectCategory: (FieldGuideCatalogIndex.CategorySummary) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            List {
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
            }
            .listStyle(.plain)
            .listRowSpacing(FieldGuideHubTileLayout.listRowSpacing)
            .scrollContentBackground(.hidden)
            .background(Color.clear)

            FieldGuideHubTitleScrollScrim(
                topChromeInset: topChromeInset,
                statusBarSafeAreaTop: statusBarSafeAreaTop
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .zIndex(0.5)
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.summaries == rhs.summaries
            && lhs.topChromeInset == rhs.topChromeInset
            && lhs.statusBarSafeAreaTop == rhs.statusBarSafeAreaTop
    }
}

/// Page-tinted fade from the status bar through hub chrome into scrolling tiles.
private struct FieldGuideHubTitleScrollScrim: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let topChromeInset: CGFloat
    let statusBarSafeAreaTop: CGFloat

    private var bandHeight: CGFloat {
        FieldGuideHubTileLayout.hubScrollScrimHeight(topChromeInset: topChromeInset)
    }

    var body: some View {
        Group {
            if reduceTransparency {
                AppTheme.Colors.surfaceGradientTop.opacity(0.98)
            } else {
                LinearGradient(
                    stops: [
                        .init(color: AppTheme.Colors.surfaceGradientTop, location: 0.0),
                        .init(color: AppTheme.Colors.surfaceGradientTop.opacity(0.92), location: 0.62),
                        .init(color: AppTheme.Colors.surfaceGradientTop.opacity(0), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(height: bandHeight, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.top, -statusBarSafeAreaTop)
        .ignoresSafeArea(edges: .top)
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
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)

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
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(.white)
            }
            .padding(.top, 2)
    }
}

/// Hub tile layout — full-width list rows aligned with **`LogbookActivityRowLayout`** spacing.
enum FieldGuideHubTileLayout: Sendable {
    nonisolated static let listRowSpacing: CGFloat = AppTheme.Spacing.sm
    nonisolated static let tileHeight: CGFloat = HomeLifetimeStatsTilesLayout.statTileHeight
    nonisolated static let tilePadding: CGFloat = LogbookActivityRowLayout.cardPadding
    nonisolated static let tileCornerRadius: CGFloat = LogbookActivityRowLayout.cardCornerRadius
    nonisolated static let hubTitleScrollFeather: CGFloat = 44

    nonisolated static func hubScrollScrimHeight(topChromeInset: CGFloat) -> CGFloat {
        topChromeInset + hubTitleScrollFeather
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

struct FieldGuideCategoryDetailView: View, Equatable {
    let categoryID: String
    let summary: FieldGuideCatalogIndex.CategorySummary
    let onSelectSubcategory: (String) -> Void

    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool

    private var definition: FieldGuideTaxonomy.Category? {
        FieldGuideTaxonomy.category(id: categoryID)
    }

    var body: some View {
        FieldGuideCategoryBlueSheetPage(
            categoryID: categoryID,
            systemImage: definition?.systemImage ?? "leaf",
            heroImageName: definition?.heroImageName,
            accessibilityRootIdentifier: "FieldGuide.CategoryDetail.Root",
            scrollAccessibilityIdentifier: "FieldGuide.CategoryDetail.Scroll",
            searchText: $searchQuery,
            isSearchFocused: $isSearchFocused,
            searchPlaceholder: "Search groups",
            searchFieldAccessibilityIdentifier: "FieldGuide.CategoryDetail.Search",
            cancelAccessibilityIdentifier: "FieldGuide.CategoryDetail.SearchCancel"
        ) {
            if let definition {
                FieldGuideCategoryDetailCopy(
                    definition: definition,
                    categoryID: categoryID,
                    speciesCount: summary.speciesCount
                )
            }
        } scrollContent: {
            if let definition {
                categoryScrollContent(definition: definition)
            }
        }
    }

    @ViewBuilder
    private func categoryScrollContent(definition: FieldGuideTaxonomy.Category) -> some View {
        let filteredSubcategories = FieldGuideSubcategorySearchPresentation.filtering(
            definition.subcategories,
            query: searchQuery
        )
        let showsAllSpeciesFallback = FieldGuideSubcategorySearchPresentation.showsAllSpeciesFallback(
            subcategories: definition.subcategories,
            speciesCount: summary.speciesCount,
            query: searchQuery
        )

        if filteredSubcategories.isEmpty,
           !showsAllSpeciesFallback,
           FieldGuideSubcategorySearchPresentation.isFiltering(query: searchQuery) {
            CatalogSearchEmptyState(
                title: "No matching groups",
                message: "Try a group name or hint like “angelfish” or “barrel sponge”."
            )
            .padding(.vertical, AppTheme.Spacing.lg)
        } else {
            FieldGuideSubcategoryListSection(
                subcategories: filteredSubcategories,
                counts: summary.subcategoryCounts,
                categoryID: categoryID,
                speciesCount: summary.speciesCount,
                showsAllSpeciesFallback: showsAllSpeciesFallback,
                onSelect: onSelectSubcategory
            )
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.categoryID == rhs.categoryID && lhs.summary == rhs.summary
    }
}

/// Title, description, and species count below the category hero.
struct FieldGuideCategoryDetailCopy: View {
    let definition: FieldGuideTaxonomy.Category
    let categoryID: String
    let speciesCount: Int

    var body: some View {
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
    var showsAllSpeciesFallback: Bool = false
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if showsAllSpeciesFallback {
                Button {
                    onSelect("")
                } label: {
                    FieldGuideSubcategoryFallbackRow(
                        title: "All species",
                        hint: "Browse every species in this category",
                        speciesCount: speciesCount,
                        categoryID: categoryID
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("FieldGuide.Category.\(categoryID).Subcategory.all")
            }

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

private struct FieldGuideSubcategoryFallbackRow: View {
    let title: String
    let hint: String
    let speciesCount: Int
    let categoryID: String

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(FieldGuideCategoryAccent.gradientTop(categoryID).opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: "list.bullet")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(FieldGuideCategoryAccent.gradientTop(categoryID))
            }

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
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
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

struct FieldGuideSubcategorySpeciesView: View, Equatable {
    let payload: FieldGuideCatalogIndex.SubcategoryBrowsePayload
    let unitSystem: DiveDisplayUnitSystem
    let onSelectSpecies: (String) -> Void

    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.md),
        GridItem(.flexible(), spacing: AppTheme.Spacing.md),
    ]

    private var categoryDefinition: FieldGuideTaxonomy.Category? {
        FieldGuideTaxonomy.category(id: payload.categoryID)
    }

    private var subcategoryDefinition: FieldGuideTaxonomy.Subcategory? {
        FieldGuideTaxonomy.subcategory(
            categoryID: payload.categoryID,
            subcategoryID: payload.subcategoryID
        )
    }

    private var filteredSpecies: [MarineLifeCatalogSnapshot] {
        FieldGuideMarineLifeSearch.filtering(payload.species, query: searchQuery)
    }

    var body: some View {
        FieldGuideCategoryBlueSheetPage(
            categoryID: payload.categoryID,
            systemImage: subcategoryDefinition?.systemImage
                ?? categoryDefinition?.systemImage
                ?? "leaf",
            heroImageName: categoryDefinition?.heroImageName,
            accessibilityRootIdentifier: "FieldGuide.SubcategoryDetail.Root",
            scrollAccessibilityIdentifier: "FieldGuide.SubcategoryDetail.Scroll",
            searchText: $searchQuery,
            isSearchFocused: $isSearchFocused,
            searchPlaceholder: "Search species",
            searchFieldAccessibilityIdentifier: "FieldGuide.SubcategoryDetail.Search",
            cancelAccessibilityIdentifier: "FieldGuide.SubcategoryDetail.SearchCancel"
        ) {
            FieldGuideSubcategoryDetailCopy(
                title: payload.title,
                hint: subcategoryDefinition?.hint ?? "",
                speciesCount: payload.species.count,
                categoryID: payload.categoryID
            )
        } scrollContent: {
            subcategoryScrollContent
        }
    }

    @ViewBuilder
    private var subcategoryScrollContent: some View {
        if filteredSpecies.isEmpty {
            if FieldGuideMarineLifeSearch.isFiltering(query: searchQuery) {
                CatalogSearchEmptyState(
                    title: "No matching species",
                    message: "Try a common name, scientific name, or family like “ray” or “angelfish”."
                )
                .padding(.vertical, AppTheme.Spacing.lg)
            } else {
                emptyState
            }
        } else {
            LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
                ForEach(filteredSpecies, id: \.uuid) { entry in
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
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.payload == rhs.payload && lhs.unitSystem == rhs.unitSystem
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

/// Title, hint, and species count below the subcategory hero (same copy stack as category detail).
struct FieldGuideSubcategoryDetailCopy: View {
    let title: String
    let hint: String
    let speciesCount: Int
    let categoryID: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

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
