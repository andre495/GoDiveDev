import SwiftUI

/// Scripted Field Guide hub → Fishes → French Angelfish for onboarding.
struct OnboardingMarineSpeciesDemoView: View {
  let isActive: Bool
  var maxPhoneHeight: CGFloat = OnboardingDemoPhoneFrameMetrics.defaultMaxHeight

  @State private var screen: Screen = .hub
  @State private var highlightedCategoryID: String?
  @State private var highlightedSubcategoryID: String?
  @State private var hubScrollTargetID: String?
  @State private var categoryScrollTargetID: String?
  @State private var demoTask: Task<Void, Never>?

  @Environment(\.diveDisplayUnitSystem) private var unitSystem

  private enum Screen {
    case hub
    case category
    case speciesDetail
  }

  private enum Layout {
    static let statusBarInset: CGFloat = 54
    static let headerHeight: CGFloat = 56
    static let heroHeight = OnboardingMarineSpeciesDemoFixtures.heroHeight
    static let panelOverlap = OnboardingMarineSpeciesDemoFixtures.panelOverlap
    static let pinnedSummaryHeight: CGFloat = 76
    static let subcategoryThumbnailSize = FieldGuideCategoryPresentation.subcategoryRowThumbnailSize
  }

  private var frenchAngelfish: MarineLifeCatalogSnapshot {
    OnboardingMarineSpeciesDemoFixtures.frenchAngelfishSnapshot
  }

  var body: some View {
    OnboardingDemoPhoneFrame(maxHeight: maxPhoneHeight) {
      ZStack {
        switch screen {
        case .hub:
          hubScene
            .transition(
              .asymmetric(
                insertion: .opacity,
                removal: .move(edge: .leading).combined(with: .opacity)
              )
            )
        case .category:
          categoryScene
            .transition(
              .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
              )
            )
        case .speciesDetail:
          speciesDetailScene
            .transition(
              .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .opacity
              )
            )
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(AppTheme.Colors.surface)
    }
    .frame(maxWidth: .infinity)
    .allowsHitTesting(false)
    .environment(\.diveDisplayUnitSystem, .imperial)
    .accessibilityHidden(true)
    .onChange(of: isActive) { _, active in
      if active {
        startDemoLoop()
      } else {
        stopDemoLoop()
      }
    }
    .onAppear {
      if isActive {
        startDemoLoop()
      }
    }
    .onDisappear {
      stopDemoLoop()
    }
  }

  // MARK: - Hub

  private var hubScene: some View {
    VStack(spacing: 0) {
      Color.clear
        .frame(height: Layout.statusBarInset)
        .accessibilityHidden(true)

      fieldGuideHeader(title: FieldGuideHubPresentation.tabTitle, showsAddButton: true)

      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: FieldGuideHubTileLayout.listRowSpacing) {
            ForEach(OnboardingMarineSpeciesDemoFixtures.hubCategories) { row in
              hubCategoryTile(row)
                .id(row.categoryID)
            }
          }
          .padding(.horizontal, AppTheme.Spacing.lg)
          .padding(.vertical, AppTheme.Spacing.sm)
        }
        .scrollIndicators(.hidden)
        .onChange(of: hubScrollTargetID) { _, targetID in
          guard let targetID else { return }
          withAnimation(.easeInOut(duration: 0.95)) {
            proxy.scrollTo(targetID, anchor: .center)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func hubCategoryTile(_ row: OnboardingFieldGuideDemoCategoryRow) -> some View {
    if let definition = FieldGuideTaxonomy.category(id: row.categoryID) {
      let isHighlighted = highlightedCategoryID == row.categoryID

      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: FieldGuideHubTileLayout.tileCornerRadius, style: .continuous)
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
          Image(heroImageName)
            .resizable()
            .scaledToFit()
            .scaleEffect(0.7, anchor: .topTrailing)
            .rotationEffect(.degrees(10), anchor: .topTrailing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(AppTheme.Spacing.sm)
            .opacity(0.36)
            .blendMode(.screen)
            .allowsHitTesting(false)
        }

        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
          VStack(alignment: .leading, spacing: 4) {
            Text(definition.title)
              .font(.headline.weight(.semibold))
              .foregroundStyle(.white)
              .lineLimit(1)

            Text(definition.subtitle)
              .font(.caption)
              .foregroundStyle(.white.opacity(0.88))
              .lineLimit(2)

            Text("\(row.speciesCount) species")
              .font(.caption2.weight(.bold))
              .foregroundStyle(FieldGuideCategoryAccent.gradientTop(definition.id))
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background {
                Capsule().fill(.white)
              }
              .padding(.top, 2)
          }

          Spacer(minLength: 72)
        }
        .padding(FieldGuideHubTileLayout.tilePadding)
      }
      .frame(height: FieldGuideHubTileLayout.tileHeight)
      .clipShape(RoundedRectangle(cornerRadius: FieldGuideHubTileLayout.tileCornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: FieldGuideHubTileLayout.tileCornerRadius, style: .continuous)
          .stroke(.white.opacity(0.18), lineWidth: 1)
      }
      .overlay {
        if isHighlighted {
          RoundedRectangle(cornerRadius: FieldGuideHubTileLayout.tileCornerRadius, style: .continuous)
            .stroke(AppTheme.Colors.accentDeep, lineWidth: 2)
        }
      }
      .scaleEffect(isHighlighted ? 1.02 : 1)
    }
  }

  // MARK: - Category

  private var categoryScene: some View {
    VStack(spacing: 0) {
      Color.clear
        .frame(height: Layout.statusBarInset)
        .accessibilityHidden(true)

      fieldGuideHeader(
        title: FieldGuideTaxonomy.category(id: OnboardingMarineSpeciesDemoFixtures.fishesCategoryID)?.title
          ?? "Fishes",
        showsAddButton: true
      )

      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if let definition = FieldGuideTaxonomy.category(
              id: OnboardingMarineSpeciesDemoFixtures.fishesCategoryID
            ) {
              Text(definition.description)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

              Text("286 species in catalog")
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                  FieldGuideCategoryAccent.gradientTop(OnboardingMarineSpeciesDemoFixtures.fishesCategoryID)
                )
            }

            LazyVStack(spacing: AppTheme.Spacing.sm) {
              ForEach(OnboardingMarineSpeciesDemoFixtures.fishesSubcategoryRows) { row in
                subcategoryRow(row)
                  .id(row.id)
              }
            }
          }
          .padding(.horizontal, AppTheme.Spacing.lg)
          .padding(.vertical, AppTheme.Spacing.sm)
        }
        .scrollIndicators(.hidden)
        .onChange(of: categoryScrollTargetID) { _, targetID in
          guard let targetID else { return }
          withAnimation(.easeInOut(duration: 0.95)) {
            proxy.scrollTo(targetID, anchor: .center)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func subcategoryRow(_ row: OnboardingFieldGuideDemoSubcategoryRow) -> some View {
    let categoryID = OnboardingMarineSpeciesDemoFixtures.fishesCategoryID
    let isHighlighted = highlightedSubcategoryID == row.id

    if let subcategory = FieldGuideTaxonomy.subcategory(
      categoryID: categoryID,
      subcategoryID: row.id
    ) {
      let accent = FieldGuideCategoryAccent.gradientTop(categoryID)

      HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
        subcategoryThumbnail(
          categoryID: categoryID,
          systemImage: subcategory.systemImage,
          usesSpeciesPhoto: row.id == OnboardingMarineSpeciesDemoFixtures.angelfishesSubcategoryID
        )

        VStack(alignment: .leading, spacing: 4) {
          Text(subcategory.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .lineLimit(1)

          Text(subcategory.hint)
            .font(.footnote)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .lineLimit(2)
        }

        Spacer(minLength: AppTheme.Spacing.sm)

        VStack(alignment: .trailing, spacing: 4) {
          Text("\(row.speciesCount)")
            .font(.caption.weight(.bold))
            .foregroundStyle(accent)
          Image(systemName: "chevron.right")
            .font(.caption2.weight(.bold))
            .foregroundStyle(AppTheme.Colors.tabUnselected)
        }
      }
      .padding(LogbookActivityRowLayout.cardPadding)
      .background {
        RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius, style: .continuous)
          .fill(AppTheme.Colors.surfaceElevated)
      }
      .overlay {
        RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius, style: .continuous)
          .stroke(accent.opacity(isHighlighted ? 0.55 : 0.18), lineWidth: isHighlighted ? 2 : 1)
      }
      .scaleEffect(isHighlighted ? 1.02 : 1)
    }
  }

  @ViewBuilder
  private func subcategoryThumbnail(
    categoryID: String,
    systemImage: String,
    usesSpeciesPhoto: Bool
  ) -> some View {
    if usesSpeciesPhoto {
      FieldGuideMarineLifeCatalogImage(
        imageURLString: "",
        bundleResourceName: OnboardingMarineSpeciesDemoFixtures.frenchAngelfishImageResourceName,
        placement: .mediaSheetHero(
          height: Layout.subcategoryThumbnailSize,
          cornerRadius: 10,
          contentMode: .fill
        )
      )
      .frame(width: Layout.subcategoryThumbnailSize, height: Layout.subcategoryThumbnailSize)
    } else {
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(FieldGuideCategoryAccent.gradientTop(categoryID).opacity(0.14))
        Image(systemName: systemImage)
          .font(.body.weight(.semibold))
          .foregroundStyle(FieldGuideCategoryAccent.gradientTop(categoryID))
      }
      .frame(width: Layout.subcategoryThumbnailSize, height: Layout.subcategoryThumbnailSize)
    }
  }

  // MARK: - Species detail

  private var speciesDetailScene: some View {
    ZStack(alignment: .top) {
      VStack(spacing: 0) {
        speciesHero
        speciesBlueSheetPanel
      }

      VStack(spacing: 0) {
        Color.clear
          .frame(height: Layout.statusBarInset)
          .accessibilityHidden(true)

        speciesTopChrome
        Spacer(minLength: 0)
      }
    }
  }

  private var speciesHero: some View {
    FieldGuideMarineLifeCatalogImage(
      imageURLString: frenchAngelfish.featureImageURL,
      bundleResourceName: frenchAngelfish.featureImageResourceName,
      placement: .mediaSheetHero(
        height: Layout.heroHeight,
        contentMode: .fill
      )
    )
    .frame(height: Layout.heroHeight)
    .frame(maxWidth: .infinity)
    .clipped()
  }

  private var speciesTopChrome: some View {
    HStack(spacing: AppTheme.Spacing.sm) {
      Image(systemName: "chevron.left")
        .appToolbarIconButtonLabel()
        .frame(width: 44, height: 44)
        .background {
          Circle()
            .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
        }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, AppTheme.Spacing.md)
    .padding(.top, AppTheme.Spacing.sm)
  }

  private var speciesBlueSheetPanel: some View {
    let accent = FieldGuideCategoryAccent.gradientTop(frenchAngelfish.category)
    let taxonomy = OnboardingMarineSpeciesDemoFixtures.taxonomyLabel(for: frenchAngelfish)

    return VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
      BlueSheetPinnedSummary(
        accent: taxonomy.isEmpty ? nil : taxonomy,
        accentColor: accent,
        title: frenchAngelfish.commonName,
        subtitle: frenchAngelfish.scientificName,
        subtitleFont: .title3.italic(),
        accessibilityIdentifier: "OnboardingMarineSpeciesDemo.SpeciesTitle"
      )
      .frame(height: Layout.pinnedSummaryHeight, alignment: .top)

      ScrollView {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
          speciesStatSection

          speciesSection(title: "About") {
            Text(OnboardingMarineSpeciesDemoFixtures.frenchAngelfishAboutText)
              .font(.body)
              .foregroundStyle(AppTheme.Colors.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
          }

          speciesSection(title: "Distinctive features") {
            Text(frenchAngelfish.distinctiveFeatures)
              .font(.body)
              .foregroundStyle(AppTheme.Colors.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(.top, AppTheme.Spacing.sm)
        .padding(.bottom, AppTheme.Spacing.lg)
      }
      .scrollIndicators(.hidden)
    }
    .padding(.horizontal, AppTheme.Spacing.md)
    .padding(.top, AppTheme.Spacing.sm)
    .padding(.bottom, AppTheme.Spacing.md)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(.thinMaterial)
    }
    .offset(y: -Layout.panelOverlap)
  }

  private var speciesStatSection: some View {
    speciesSection(title: "At a glance") {
      detailRow(
        label: "Typical size",
        value: FieldGuidePresentation.sizeRangeLine(
          minMeters: frenchAngelfish.minSizeMeters,
          maxMeters: frenchAngelfish.maxSizeMeters,
          unitSystem: unitSystem
        )
      )
      detailRow(
        label: "Depth range",
        value: FieldGuidePresentation.depthLine(
          minMeters: frenchAngelfish.minDepthMeters,
          maxMeters: frenchAngelfish.maxDepthMeters,
          avgMeters: frenchAngelfish.avgDepthMeters,
          unitSystem: unitSystem
        )
      )
    }
  }

  private func speciesSection(title: String, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
      Text(title)
        .font(.headline.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.textPrimary)

      VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
        content()
      }
      .padding(AppTheme.Spacing.md)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(AppTheme.Colors.surfaceElevated)
      }
    }
  }

  private func detailRow(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.secondaryText)
      Text(value)
        .font(.body)
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func fieldGuideHeader(title: String, showsAddButton: Bool) -> some View {
    HStack(spacing: AppTheme.Spacing.sm) {
      if screen != .hub {
        Image(systemName: "chevron.left")
          .appToolbarIconButtonLabel()
          .frame(width: 44, height: 44)
          .background {
            Circle()
              .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
          }
      }

      Text(title)
        .font(.title2.weight(.bold))
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .lineLimit(1)

      Spacer(minLength: 0)

      if showsAddButton {
        Image(systemName: "plus")
          .appToolbarIconButtonLabel()
          .frame(width: 44, height: 44)
          .background {
            Circle()
              .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
          }
      }
    }
    .padding(.horizontal, AppTheme.Spacing.md)
    .frame(height: Layout.headerHeight)
    .background(AppTheme.Colors.surface.opacity(0.96))
  }

  // MARK: - Timeline

  private func startDemoLoop() {
    stopDemoLoop()
    demoTask = Task { @MainActor in
      resetDemoState()
      while !Task.isCancelled {
        await runDemoCycle()
        try? await Task.sleep(for: .milliseconds(500))
      }
    }
  }

  private func stopDemoLoop() {
    demoTask?.cancel()
    demoTask = nil
  }

  private func resetDemoState() {
    screen = .hub
    highlightedCategoryID = nil
    highlightedSubcategoryID = nil
    hubScrollTargetID = nil
    categoryScrollTargetID = nil
  }

  @MainActor
  private func runDemoCycle() async {
    resetDemoState()
    guard !Task.isCancelled else { return }

    try? await Task.sleep(for: .milliseconds(900))
    guard !Task.isCancelled else { return }

    hubScrollTargetID = OnboardingMarineSpeciesDemoFixtures.fishesCategoryID
    try? await Task.sleep(for: .milliseconds(850))
    guard !Task.isCancelled else { return }

    withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
      highlightedCategoryID = OnboardingMarineSpeciesDemoFixtures.fishesCategoryID
    }
    try? await Task.sleep(for: .milliseconds(700))
    guard !Task.isCancelled else { return }

    withAnimation(.easeInOut(duration: 0.42)) {
      screen = .category
      highlightedCategoryID = nil
    }
    try? await Task.sleep(for: .milliseconds(900))
    guard !Task.isCancelled else { return }

    categoryScrollTargetID = OnboardingMarineSpeciesDemoFixtures.angelfishesSubcategoryID
    try? await Task.sleep(for: .milliseconds(850))
    guard !Task.isCancelled else { return }

    withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
      highlightedSubcategoryID = OnboardingMarineSpeciesDemoFixtures.angelfishesSubcategoryID
    }
    try? await Task.sleep(for: .milliseconds(700))
    guard !Task.isCancelled else { return }

    withAnimation(.easeInOut(duration: 0.42)) {
      screen = .speciesDetail
      highlightedSubcategoryID = nil
    }
    try? await Task.sleep(for: .milliseconds(2800))
  }
}

#Preview {
  OnboardingMarineSpeciesDemoView(isActive: true)
    .padding()
    .background(AppTheme.Colors.surface)
}
