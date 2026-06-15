import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Category hub (bento grid)

struct FieldGuideCatalogHubView: View, Equatable {
    let summaries: [FieldGuideCatalogIndex.CategorySummary]
    let onSelectCategory: (FieldGuideCatalogIndex.CategorySummary) -> Void

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
                                onSelectCategory(summary)
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

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.summaries == rhs.summaries
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
                hubTileTitle(definition.title)

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

    private func hubTileTitle(_ title: String) -> some View {
        Text(title)
            .font(isFeatured ? .title3.weight(.bold) : .headline.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .frame(
                maxWidth: .infinity,
                minHeight: FieldGuideHubTileLayout.titleTwoLineMinHeight(isFeatured: isFeatured),
                alignment: .topLeading
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
                Capsule().fill(.white.opacity(0.92))
            }
            .padding(.top, 2)
    }
}

/// Hub tile title block height — reserves two lines so short category names align in the bento grid.
enum FieldGuideHubTileLayout: Sendable {
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

    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback

    private var definition: FieldGuideTaxonomy.Category? {
        FieldGuideTaxonomy.category(id: categoryID)
    }

    var body: some View {
        AppHeaderlessPage {
            GeometryReader { proxy in
                let safeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(proxy.safeAreaInsets.top)
                let topInset = AppScrollUnderHeaderListLayout.listTopInset(
                    safeAreaTop: safeTop,
                    headerClearance: headerClearance
                )

                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if let definition {
                                FieldGuideCategoryHeroImage(
                                    categoryID: categoryID,
                                    systemImage: definition.systemImage,
                                    heroImageName: definition.heroImageName,
                                    totalHeight: FieldGuideCategoryPresentation.detailHeroHeight(
                                        extraTopInset: safeTop
                                    ),
                                    fullBleed: true
                                )

                                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                                    FieldGuideCategoryDetailCopy(
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
                                .padding(AppTheme.Spacing.md)
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .ignoresSafeArea(edges: .top)

                    LogbookTopChromeScrim(topObstructionHeight: topInset)
                        .padding(.top, -safeTop)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                        .zIndex(0.5)

                    Color.clear
                        .frame(height: topInset)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)
                        .zIndex(0.75)

                    AppHeader(
                        title: "",
                        showsBackButton: true,
                        showsBrandWordmark: false,
                        statusBarSafeAreaTop: safeTop
                    ) {
                        EmptyView()
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .zIndex(1)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                    if height > 0 { headerClearance = height }
                }
            }
        }
        .hidesBottomTabBarWhenPushed()
        .accessibilityIdentifier("FieldGuide.CategoryDetail.Root")
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

struct FieldGuideSubcategorySpeciesView: View, Equatable {
    let payload: FieldGuideCatalogIndex.SubcategoryBrowsePayload
    let unitSystem: DiveDisplayUnitSystem
    let onSelectSpecies: (String) -> Void

    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback

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

    var body: some View {
        AppHeaderlessPage {
            GeometryReader { proxy in
                let safeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(proxy.safeAreaInsets.top)
                let topInset = AppScrollUnderHeaderListLayout.listTopInset(
                    safeAreaTop: safeTop,
                    headerClearance: headerClearance
                )

                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if let categoryDefinition {
                                FieldGuideCategoryHeroImage(
                                    categoryID: payload.categoryID,
                                    systemImage: subcategoryDefinition?.systemImage
                                        ?? categoryDefinition.systemImage,
                                    heroImageName: categoryDefinition.heroImageName,
                                    totalHeight: FieldGuideCategoryPresentation.detailHeroHeight(
                                        extraTopInset: safeTop
                                    ),
                                    fullBleed: true
                                )

                                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                                    FieldGuideSubcategoryDetailCopy(
                                        title: payload.title,
                                        hint: subcategoryDefinition?.hint ?? "",
                                        speciesCount: payload.species.count,
                                        categoryID: payload.categoryID
                                    )

                                    Group {
                                        if payload.species.isEmpty {
                                            emptyState
                                        } else {
                                            LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
                                                ForEach(payload.species, id: \.uuid) { entry in
                                                    Button {
                                                        onSelectSpecies(entry.uuid)
                                                    } label: {
                                                        FieldGuideSpeciesMosaicCard(
                                                            entry: entry,
                                                            unitSystem: unitSystem,
                                                            accent: FieldGuideCategoryAccent.gradientTop(
                                                                payload.categoryID
                                                            )
                                                        )
                                                        .equatable()
                                                    }
                                                    .buttonStyle(.plain)
                                                    .accessibilityIdentifier("FieldGuide.Species.\(entry.uuid)")
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(AppTheme.Spacing.md)
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .ignoresSafeArea(edges: .top)

                    LogbookTopChromeScrim(topObstructionHeight: topInset)
                        .padding(.top, -safeTop)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                        .zIndex(0.5)

                    Color.clear
                        .frame(height: topInset)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)
                        .zIndex(0.75)

                    AppHeader(
                        title: "",
                        showsBackButton: true,
                        showsBrandWordmark: false,
                        statusBarSafeAreaTop: safeTop
                    ) {
                        EmptyView()
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .zIndex(1)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                    if height > 0 { headerClearance = height }
                }
            }
        }
        .hidesBottomTabBarWhenPushed()
        .accessibilityIdentifier("FieldGuide.SubcategoryDetail.Root")
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
