import SwiftUI

/// Scripted logbook → dive detail → map / tank / media tab tour for onboarding.
struct OnboardingLogEveryDiveDemoView: View {
  let isActive: Bool
  var maxPhoneHeight: CGFloat = OnboardingDemoPhoneFrameMetrics.defaultMaxHeight

  @State private var screen: Screen = .logbook
  @State private var selectedTab: DiveActivityTab = .map
  @State private var highlightedRowID: UUID?
  @State private var scrollTargetID: UUID?
  @State private var tankPressureFill: CGFloat = 1
  @State private var chartRevealProgress: CGFloat = 0
  @State private var demoTask: Task<Void, Never>?

  private enum Screen {
    case logbook
    case diveDetail
  }

  private enum Layout {
    static let statusBarInset: CGFloat = 54
    static let logbookHeaderHeight: CGFloat = 56
    static let diveChromeHeight: CGFloat = 64
    static let overviewPanelHeight: CGFloat =
      DiveActivityMapOverviewStatsBox.estimatedExpandedHeight + AppTheme.Spacing.md * 2 + 44
    static let logbookMediaThumbnailExtent: CGFloat = DiveActivityMediaPresentation.logbookRowMediaPreviewMinExtent
  }

  var body: some View {
    OnboardingDemoPhoneFrame(maxHeight: maxPhoneHeight) {
      ZStack {
        switch screen {
        case .logbook:
          logbookScene
            .transition(
              .asymmetric(
                insertion: .opacity,
                removal: .move(edge: .leading).combined(with: .opacity)
              )
            )
        case .diveDetail:
          diveDetailScene
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

  // MARK: - Logbook

  private var logbookScene: some View {
    VStack(spacing: 0) {
      Color.clear
        .frame(height: Layout.statusBarInset)
        .accessibilityHidden(true)

      logbookHeader

      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: AppTheme.Spacing.sm) {
            ForEach(OnboardingLogEveryDiveDemoFixtures.logbookRows) { row in
              demoLogbookRow(row)
                .id(row.id)
            }
          }
          .padding(.horizontal, AppTheme.Spacing.md)
          .padding(.vertical, AppTheme.Spacing.sm)
        }
        .scrollIndicators(.hidden)
        .onChange(of: scrollTargetID) { _, targetID in
          guard let targetID else { return }
          withAnimation(.easeInOut(duration: 1.1)) {
            proxy.scrollTo(targetID, anchor: .center)
          }
        }
      }
    }
  }

  private var logbookHeader: some View {
    HStack(spacing: AppTheme.Spacing.sm) {
      Text(LogbookCollapsibleHeaderPresentation.title)
        .font(.title2.weight(.bold))
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .lineLimit(1)

      Spacer(minLength: 0)

      Image(systemName: TripPlannerPresentation.exploreChromeSystemImage)
        .font(.body.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.tabUnselected)
        .frame(width: 44, height: 44)
        .background {
          Circle()
            .fill(AppTheme.Colors.surfaceElevated.opacity(0.9))
        }

      Image(systemName: "plus")
        .font(.body.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.tabUnselected)
        .frame(width: 44, height: 44)
        .background {
          Circle()
            .fill(AppTheme.Colors.surfaceElevated.opacity(0.9))
        }
    }
    .padding(.horizontal, AppTheme.Spacing.md)
    .frame(height: Layout.logbookHeaderHeight)
    .background(AppTheme.Colors.surface.opacity(0.96))
  }

  private func demoLogbookRow(_ row: DiveLogbookRowDisplayData) -> some View {
    let isHighlighted = highlightedRowID == row.id
    let showsDemoThumbnail = row.id == OnboardingLogEveryDiveDemoFixtures.focusedDiveID

    return HStack(alignment: .top, spacing: 0) {
      VStack(alignment: .leading, spacing: LogbookActivityRowLayout.contentSpacing) {
        HStack(spacing: 6) {
          if let symbol = row.diveNumberLeadingSymbolName {
            Image(systemName: symbol)
              .font(.caption.weight(.semibold))
              .foregroundStyle(AppTheme.Colors.accent)
          }
          ActivityTagOvalChipLabel(
            title: row.diveNumberLabel,
            isCompact: true
          )
        }

        Text(row.displayName)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(AppTheme.Colors.textPrimary)
          .lineLimit(1)

        Text(row.detailLine)
          .font(.caption)
          .foregroundStyle(AppTheme.Colors.secondaryText)
          .lineLimit(2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if showsDemoThumbnail {
        Spacer(minLength: LogbookActivityRowLayout.previewGap)
        OnboardingDemoMarineLifeThumbnail(
          bundleResourceName: OnboardingLogEveryDiveDemoFixtures.logbookThumbnailSpeciesResourceName,
          side: Layout.logbookMediaThumbnailExtent
        )
      }
    }
    .padding(LogbookActivityRowLayout.cardPadding)
    .background {
      RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius)
        .fill(AppListTileCardChrome.fill)
    }
    .overlay {
      RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius)
        .stroke(AppListTileCardChrome.stroke, lineWidth: AppListTileCardChrome.strokeWidth)
    }
    .overlay {
      if isHighlighted {
        RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius)
          .stroke(AppTheme.Colors.accentDeep, lineWidth: 2)
      }
    }
    .scaleEffect(isHighlighted ? 1.02 : 1)
  }

  // MARK: - Dive detail

  private var diveDetailScene: some View {
    ZStack(alignment: .top) {
      diveHero
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      VStack(spacing: 0) {
        Color.clear
          .frame(height: Layout.statusBarInset)
          .accessibilityHidden(true)

        diveTopChrome
        Spacer(minLength: 0)
        diveOverviewPanel
      }
    }
  }

  private var diveTopChrome: some View {
    HStack(spacing: AppTheme.Spacing.sm) {
      Image(systemName: "chevron.left")
        .font(.body.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .frame(width: 44, height: 44)
        .background {
          Circle()
            .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
        }

      Spacer(minLength: 0)

      DiveActivityIconTabBar(selection: $selectedTab) { tab in
        selectedTab = tab
      }
    }
    .padding(.horizontal, AppTheme.Spacing.md)
    .padding(.top, AppTheme.Spacing.sm)
    .frame(height: Layout.diveChromeHeight, alignment: .top)
  }

  @ViewBuilder
  private var diveHero: some View {
    switch selectedTab {
    case .map:
      mapHero
    case .tank:
      tankHero
    case .camera:
      mediaHero
    }
  }

  private var mapHero: some View {
    ZStack {
      #if canImport(UIKit)
      OnboardingLogEveryDiveMapRepresentable(
        coordinate: OnboardingLogEveryDiveDemoFixtures.diveCoordinate,
        region: OnboardingLogEveryDiveDemoFixtures.mapRegion
      )
      #else
      LinearGradient(
        colors: [
          Color(red: 0.18, green: 0.52, blue: 0.78),
          Color(red: 0.08, green: 0.28, blue: 0.48),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      #endif
    }
  }

  private var tankHero: some View {
    ZStack {
      AppTheme.Colors.surfaceMuted

      HStack(alignment: .bottom, spacing: AppTheme.Spacing.md) {
        OnboardingDemoAnimatedDepthChart(
          samples: OnboardingLogEveryDiveDemoFixtures.depthSamples,
          revealProgress: chartRevealProgress
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        DiveTankCylinderVisual(
          height: 200,
          pressureRemainingFraction: tankPressureFill
        )
        .padding(.trailing, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.lg)
      }
      .padding(.horizontal, AppTheme.Spacing.md)
      .padding(.top, Layout.statusBarInset + Layout.diveChromeHeight + AppTheme.Spacing.sm)
      .padding(.bottom, Layout.overviewPanelHeight + AppTheme.Spacing.sm)
    }
  }

  private var mediaHero: some View {
    OnboardingBundledLoopingVideoView(
      resourceName: OnboardingLogEveryDiveDemoFixtures.mediaHeroVideoResourceName,
      resourceExtension: OnboardingLogEveryDiveDemoFixtures.mediaHeroVideoResourceExtension,
      isPlaybackActive: isActive && screen == .diveDetail && selectedTab == .camera
    )
  }

  private var diveOverviewPanel: some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
      HStack(spacing: AppTheme.Spacing.sm) {
        ActivityTagOvalChipLabel(
          title: OnboardingLogEveryDiveDemoFixtures.focusedDiveNumberLabel,
          isCompact: true
        )

        VStack(alignment: .leading, spacing: 2) {
          Text(OnboardingLogEveryDiveDemoFixtures.focusedDiveName)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .lineLimit(1)

          Text(OnboardingLogEveryDiveDemoFixtures.focusedDiveLocation)
            .font(.caption)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .lineLimit(1)
        }

        Spacer(minLength: 0)
      }

      if selectedTab == .map {
        DiveActivityMapOverviewStatsBox(
          layout: OnboardingLogEveryDiveDemoFixtures.mapOverviewStatsLayout
        )
      } else if selectedTab == .tank {
        HStack(spacing: AppTheme.Spacing.md) {
          demoTankStat(title: "Start", value: "3000", unit: "psi")
          demoTankStat(title: "End", value: "1200", unit: "psi")
          demoTankStat(title: "Used", value: "1800", unit: "psi")
        }
      } else {
        demoMediaTaggedSpeciesSummary
      }
    }
    .padding(AppTheme.Spacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(height: Layout.overviewPanelHeight, alignment: .top)
    .background {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.thinMaterial)
    }
    .padding(.horizontal, AppTheme.Spacing.md)
    .padding(.bottom, AppTheme.Spacing.md)
  }

  private var demoMediaTaggedSpeciesSummary: some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
      Text(MarineLifeMediaTagPresentation.sectionTitle)
        .font(.caption.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.tabUnselected)
        .textCase(.uppercase)

      ActivityTagOvalChipLabel(
        title: MarineLifeMediaTagPresentation.chipDisplayTitle(
          for: OnboardingLogEveryDiveDemoFixtures.taggedMediaSpeciesCommonName
        )
      )

      Text(OnboardingLogEveryDiveDemoFixtures.taggedMediaSpeciesScientificName)
        .font(.caption.italic())
        .foregroundStyle(AppTheme.Colors.secondaryText)
        .lineLimit(1)

      Text(OnboardingLogEveryDiveDemoFixtures.taggedMediaSpeciesDescription)
        .font(.caption)
        .foregroundStyle(AppTheme.Colors.secondaryText)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      MarineLifeMediaTagPresentation.mediumDetentAccessibilityLabel(
        taggedNames: [OnboardingLogEveryDiveDemoFixtures.taggedMediaSpeciesCommonName]
      )
    )
  }

  private func demoTankStat(title: String, value: String, unit: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundStyle(AppTheme.Colors.secondaryText)
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(value)
          .font(.subheadline.weight(.bold))
          .foregroundStyle(AppTheme.Colors.textPrimary)
        Text(unit)
          .font(.caption)
          .foregroundStyle(AppTheme.Colors.secondaryText)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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
    screen = .logbook
    selectedTab = .map
    highlightedRowID = nil
    scrollTargetID = nil
    tankPressureFill = 1
    chartRevealProgress = 0
  }

  @MainActor
  private func runDemoCycle() async {
    resetDemoState()
    guard !Task.isCancelled else { return }

    try? await Task.sleep(for: .milliseconds(500))
    guard !Task.isCancelled else { return }

    scrollTargetID = OnboardingLogEveryDiveDemoFixtures.focusedDiveID
    try? await Task.sleep(for: .milliseconds(1200))
    guard !Task.isCancelled else { return }

    withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
      highlightedRowID = OnboardingLogEveryDiveDemoFixtures.focusedDiveID
    }
    try? await Task.sleep(for: .milliseconds(550))
    guard !Task.isCancelled else { return }

    withAnimation(.easeInOut(duration: 0.42)) {
      screen = .diveDetail
      selectedTab = .map
    }
    try? await Task.sleep(for: .milliseconds(1700))
    guard !Task.isCancelled else { return }

    withAnimation(.easeInOut(duration: 0.32)) {
      selectedTab = .tank
    }
    chartRevealProgress = 0
    withAnimation(.easeOut(duration: 1.1)) {
      chartRevealProgress = 1
      tankPressureFill = CGFloat(
        OnboardingLogEveryDiveDemoFixtures.tankPressureEndPSI
          / OnboardingLogEveryDiveDemoFixtures.tankPressureStartPSI
      )
    }
    try? await Task.sleep(for: .milliseconds(1900))
    guard !Task.isCancelled else { return }

    withAnimation(.easeInOut(duration: 0.32)) {
      selectedTab = .camera
    }
    try? await Task.sleep(for: .milliseconds(2600))
  }
}

// MARK: - Supporting views

private struct OnboardingDemoMarineLifeThumbnail: View {
  let bundleResourceName: String
  let side: CGFloat
  var showsVideoBadge: Bool = false

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      FieldGuideMarineLifeCatalogImage(
        imageURLString: "",
        bundleResourceName: bundleResourceName,
        placement: .mediaSheetHero(
          height: side,
          cornerRadius: 10,
          contentMode: .fill
        )
      )

      if showsVideoBadge {
        Image(systemName: "video.fill")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.white)
          .padding(5)
          .background {
            Circle()
              .fill(.black.opacity(0.5))
          }
          .padding(6)
          .accessibilityHidden(true)
      }
    }
    .frame(width: side, height: side)
    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
  }
}

private struct OnboardingDemoAnimatedDepthChart: View {
  let samples: [DiveDepthProfileSample]
  let revealProgress: CGFloat

  var body: some View {
    DiveDepthProfileChart(
      samples: samples,
      maxDepthHintMeters: 18.3
    )
    .mask(alignment: .leading) {
      Rectangle()
        .scaleEffect(x: max(revealProgress, 0.001), y: 1, anchor: .leading)
    }
  }
}

#Preview {
  OnboardingLogEveryDiveDemoView(isActive: true)
    .environment(AppNetworkConnectivityMonitor.shared)
    .padding()
    .background(AppTheme.Colors.surface)
}
