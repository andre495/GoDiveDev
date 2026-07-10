import SwiftUI

/// Scripted Explore map zoom / pan → dive-site pin tap → site detail for onboarding.
struct OnboardingExploreSitesDemoView: View {
  let isActive: Bool
  var maxPhoneHeight: CGFloat = OnboardingDemoPhoneFrameMetrics.defaultMaxHeight

  @State private var screen: Screen = .map
  @State private var viewMode: ExploreViewMode = .map
  @State private var siteScope: ExploreSiteScope = .allSites
  @State private var mapRegion = OnboardingExploreSitesDemoFixtures.worldOverviewRegion
  @State private var animateMapRegion = false
  @State private var selectedSiteID: UUID?
  @State private var regionToken = 0
  @State private var demoTask: Task<Void, Never>?

  private enum Screen {
    case map
    case siteDetail
  }

  private enum Layout {
    static let statusBarInset: CGFloat = 54
    static let siteDetailPanelHeight: CGFloat = 168
  }

  var body: some View {
    OnboardingDemoPhoneFrame(maxHeight: maxPhoneHeight) {
      ZStack {
        switch screen {
        case .map:
          mapScene
            .transition(
              .asymmetric(
                insertion: .opacity,
                removal: .move(edge: .leading).combined(with: .opacity)
              )
            )
        case .siteDetail:
          siteDetailScene
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

  // MARK: - Map

  private var mapScene: some View {
    ZStack(alignment: .top) {
      onboardingMap(animateRegion: animateMapRegion)
        .ignoresSafeArea()

      VStack(spacing: 0) {
        exploreTopChrome
        Spacer(minLength: 0)
      }
    }
  }

  @ViewBuilder
  private func onboardingMap(animateRegion: Bool) -> some View {
    #if canImport(UIKit)
    OnboardingExploreSitesMapRepresentable(
      sites: OnboardingExploreSitesDemoFixtures.plottedSites,
      region: mapRegion,
      animateRegion: animateRegion,
      selectedSiteID: selectedSiteID,
      regionToken: regionToken
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

  private var exploreTopChrome: some View {
    ExploreTopChrome(
      viewMode: $viewMode,
      siteScope: $siteScope,
      showsSiteScopeToggle: false,
      statusBarSafeAreaTop: 0,
      onAddDiveSite: {}
    )
  }

  // MARK: - Site detail

  private var siteDetailScene: some View {
    ZStack(alignment: .top) {
      onboardingMap(animateRegion: false)
        .ignoresSafeArea()

      VStack(spacing: 0) {
        Color.clear
          .frame(height: Layout.statusBarInset)
          .accessibilityHidden(true)

        siteDetailTopChrome
        Spacer(minLength: 0)
        siteDetailPanel
      }
    }
  }

  private var siteDetailTopChrome: some View {
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

  private var siteDetailPanel: some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
      BlueSheetPinnedSummary(
        title: OnboardingExploreSitesDemoFixtures.focusedSiteName,
        subtitle: OnboardingExploreSitesDemoFixtures.focusedSiteLocation,
        accessibilityIdentifier: "OnboardingExploreSitesDemo.SiteDetail",
        topRow: {
          HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            DiveSitePinnedStarRatingView(
              rating: OnboardingExploreSitesDemoFixtures.focusedSiteStarRating
            )
            Spacer(minLength: AppTheme.Spacing.sm)
            Text(OnboardingExploreSitesDemoFixtures.focusedSiteDiveCountLabel)
              .font(BlueSheetPinnedSummaryPresentation.accentMediumFont)
              .foregroundStyle(AppTheme.Colors.accent)
              .lineLimit(1)
          }
        }
      )

      HStack(spacing: AppTheme.Spacing.md) {
        siteDetailStat(
          title: "Max depth",
          value: OnboardingExploreSitesDemoFixtures.siteDetailMaxDepthLabel
        )
        siteDetailStat(
          title: "Environment",
          value: OnboardingExploreSitesDemoFixtures.siteDetailEnvironmentLabel
        )
      }
    }
    .padding(AppTheme.Spacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(height: Layout.siteDetailPanelHeight, alignment: .top)
    .background {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.thinMaterial)
    }
    .padding(.horizontal, AppTheme.Spacing.md)
    .padding(.bottom, AppTheme.Spacing.md)
  }

  private func siteDetailStat(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundStyle(AppTheme.Colors.secondaryText)
      Text(value)
        .font(.caption.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
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
    screen = .map
    viewMode = .map
    siteScope = .allSites
    mapRegion = OnboardingExploreSitesDemoFixtures.worldOverviewRegion
    animateMapRegion = false
    selectedSiteID = nil
    regionToken = 0
  }

  @MainActor
  private func runDemoCycle() async {
    resetDemoState()
    guard !Task.isCancelled else { return }

    try? await Task.sleep(for: .milliseconds(650))
    guard !Task.isCancelled else { return }

    await animateMap(to: OnboardingExploreSitesDemoFixtures.belizeClusterRegion, duration: 1.2)
    guard !Task.isCancelled else { return }

    try? await Task.sleep(for: .milliseconds(350))
    guard !Task.isCancelled else { return }

    await animateMap(to: OnboardingExploreSitesDemoFixtures.belizePanRegion, duration: 0.9)
    guard !Task.isCancelled else { return }

    try? await Task.sleep(for: .milliseconds(300))
    guard !Task.isCancelled else { return }

    await animateMap(to: OnboardingExploreSitesDemoFixtures.focusedSiteRegion, duration: 1.0)
    selectedSiteID = OnboardingExploreSitesDemoFixtures.focusedSiteID
    guard !Task.isCancelled else { return }

    try? await Task.sleep(for: .milliseconds(900))
    guard !Task.isCancelled else { return }

    withAnimation(.easeInOut(duration: 0.42)) {
      screen = .siteDetail
      selectedSiteID = nil
      mapRegion = OnboardingExploreSitesDemoFixtures.focusedSiteRegion
      regionToken += 1
      animateMapRegion = false
    }
    try? await Task.sleep(for: .milliseconds(2200))
  }

  @MainActor
  private func animateMap(to region: DiveLocationMapRegionSpec, duration: TimeInterval) async {
    animateMapRegion = true
    mapRegion = region
    regionToken += 1
    try? await Task.sleep(for: .milliseconds(Int(duration * 1000)))
  }
}

#Preview {
  OnboardingExploreSitesDemoView(isActive: true)
    .environment(AppNetworkConnectivityMonitor.shared)
    .padding()
    .background(AppTheme.Colors.surface)
}
