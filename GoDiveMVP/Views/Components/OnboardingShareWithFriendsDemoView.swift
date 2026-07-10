import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Scripted trip detail pager → full-bleed share-card PNG preview for onboarding.
struct OnboardingShareWithFriendsDemoView: View {
  let isActive: Bool
  var maxPhoneHeight: CGFloat = OnboardingDemoPhoneFrameMetrics.defaultMaxHeight

  @State private var screen: Screen = .tripDetail
  @State private var selectedPage = OnboardingShareWithFriendsDemoFixtures.DemoPage.stats
  @State private var highlightsShareButton = false
  @State private var demoTask: Task<Void, Never>?
  #if canImport(UIKit)
  @State private var shareCardPreviewImage: UIImage?
  #endif

  private enum Screen {
    case tripDetail
    case sharePreview
  }

  private typealias DemoPage = OnboardingShareWithFriendsDemoFixtures.DemoPage
  private typealias DemoMetrics = OnboardingShareWithFriendsDemoLayout.Metrics

  var body: some View {
    OnboardingDemoPhoneFrame(maxHeight: maxPhoneHeight) {
      GeometryReader { geometry in
        let metrics = OnboardingShareWithFriendsDemoLayout.metrics(phoneSize: geometry.size)

        ZStack {
          switch screen {
          case .tripDetail:
            tripDetailScene(metrics: metrics)
              .transition(
                .asymmetric(
                  insertion: .opacity,
                  removal: .move(edge: .leading).combined(with: .opacity)
                )
              )
          case .sharePreview:
            sharePreviewScene(metrics: metrics)
              .transition(
                .asymmetric(
                  insertion: .move(edge: .trailing).combined(with: .opacity),
                  removal: .opacity
                )
              )
          }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .background(AppTheme.Colors.surface)
        .clipped()
      }
    }
    .frame(maxWidth: .infinity)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .onChange(of: isActive) { _, active in
      if active {
        scheduleShareCardPreviewWarmup()
        startDemoLoop()
      } else {
        stopDemoLoop()
      }
    }
    .onAppear {
      if isActive {
        scheduleShareCardPreviewWarmup()
        startDemoLoop()
      }
    }
    .onDisappear {
      stopDemoLoop()
    }
  }

  // MARK: - Trip detail

  private func tripDetailScene(metrics: DemoMetrics) -> some View {
    ZStack(alignment: .top) {
      VStack(spacing: -metrics.panelOverlap) {
        tripHero(metrics: metrics)
        tripBlueSheetPanel(metrics: metrics)
      }
      .frame(width: metrics.phoneSize.width, height: metrics.phoneSize.height, alignment: .top)

      VStack(spacing: 0) {
        Color.clear
          .frame(height: metrics.statusBarInset)
          .accessibilityHidden(true)

        tripTopChrome
        Spacer(minLength: 0)
      }
      .frame(width: metrics.phoneSize.width, height: metrics.phoneSize.height, alignment: .top)
    }
  }

  private func tripHero(metrics: DemoMetrics) -> some View {
    ZStack {
      #if canImport(UIKit)
      if let image = OnboardingShareWithFriendsDemoFixtures.tripHeroImage {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .clipped()
      } else {
        tripHeroPlaceholder
      }
      #else
      tripHeroPlaceholder
      #endif
    }
    .frame(width: metrics.phoneSize.width, height: metrics.heroHeight)
  }

  private var tripHeroPlaceholder: some View {
    LinearGradient(
      colors: [
        Color(red: 0.05, green: 0.22, blue: 0.38),
        Color(red: 0.12, green: 0.42, blue: 0.55),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .overlay {
      Image(systemName: "airplane.departure")
        .font(.system(size: 56, weight: .semibold))
        .foregroundStyle(.white.opacity(0.22))
        .offset(y: 16)
    }
  }

  private var tripTopChrome: some View {
    HStack(spacing: AppTheme.Spacing.sm) {
      Image(systemName: "chevron.left")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.secondaryText)
        .frame(width: 40, height: 40)
        .background {
          Circle()
            .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
        }

      Spacer(minLength: 0)

      Text("Edit")
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, AppTheme.Spacing.sm)
        .frame(height: 40)
        .background {
          Capsule()
            .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
        }
    }
    .padding(.horizontal, AppTheme.Spacing.md)
    .padding(.top, AppTheme.Spacing.sm)
  }

  private func tripBlueSheetPanel(metrics: DemoMetrics) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      tripPinnedSummary(metrics: metrics)
      tripPager(metrics: metrics)
    }
    .padding(.horizontal, AppTheme.Spacing.md)
    .padding(.top, 12)
    .padding(.bottom, 6)
    .frame(width: metrics.phoneSize.width, height: metrics.blueSheetHeight, alignment: .top)
    .background {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(.thinMaterial)
    }
  }

  private func tripPinnedSummary(metrics: DemoMetrics) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(OnboardingShareWithFriendsDemoFixtures.tripDateRange)
        .font(.caption.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.accent)
        .lineLimit(1)
        .minimumScaleFactor(0.85)

      Text(OnboardingShareWithFriendsDemoFixtures.tripTitle)
        .font(.title3.weight(.bold))
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .accessibilityIdentifier("OnboardingShareWithFriendsDemo.TripTitle")
    }
    .frame(height: metrics.pinnedSummaryHeight, alignment: .topLeading)
  }

  private func tripPager(metrics: DemoMetrics) -> some View {
    TabView(selection: $selectedPage) {
      ForEach(OnboardingShareWithFriendsDemoFixtures.demoPages) { page in
        pagerPageContent(for: page, metrics: metrics)
          .tag(page)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: .automatic))
    .frame(height: metrics.pagerHeight)
  }

  @ViewBuilder
  private func pagerPageContent(for page: DemoPage, metrics: DemoMetrics) -> some View {
    switch page {
    case .stats:
      OnboardingTripDemoStatsGrid(
        tiles: OnboardingShareWithFriendsDemoFixtures.statTiles,
        tileHeight: metrics.statTileHeight,
        gridSpacing: metrics.statGridSpacing
      )
      .padding(.top, 4)
    case .sites:
      demoSitesPage(metrics: metrics)
    case .buddies:
      demoBuddiesPage(metrics: metrics)
    }
  }

  private func demoSitesPage(metrics: DemoMetrics) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("3 planned sites")
        .font(.caption.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.secondaryText)

      ForEach(OnboardingShareWithFriendsDemoFixtures.plannedSiteRows) { row in
        demoSiteRow(row)
      }

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func demoSiteRow(_ row: OnboardingTripDemoSiteRow) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(row.displayName)
        .font(.caption.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .lineLimit(1)

      Text(row.coordinateLine)
        .font(.caption2)
        .foregroundStyle(AppTheme.Colors.secondaryText)
        .lineLimit(1)

      Text(row.placeLine)
        .font(.caption2)
        .foregroundStyle(AppTheme.Colors.secondaryText)
        .lineLimit(1)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(AppTheme.Colors.surfaceElevated)
    }
  }

  private func demoBuddiesPage(metrics: DemoMetrics) -> some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
      let columns = Array(
        repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.sm),
        count: 3
      )

      LazyVGrid(columns: columns, alignment: .center, spacing: AppTheme.Spacing.sm) {
        ForEach(OnboardingShareWithFriendsDemoFixtures.taggedBuddies) { buddy in
          demoBuddyCell(buddy, diameter: metrics.buddyAvatarDiameter)
        }
      }

      Spacer(minLength: 0)

      shareButton
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private func demoBuddyCell(_ buddy: OnboardingTripDemoBuddy, diameter: CGFloat) -> some View {
    VStack(spacing: 4) {
      ProfileAvatarView(
        profilePhoto: OnboardingShareWithFriendsDemoFixtures.profilePhotoData(for: buddy),
        diameter: diameter,
        iconFont: .caption,
        placeholderInitials: DiveBuddyPresentation.initials(from: buddy.displayName)
      )

      Text(buddy.displayName)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .lineLimit(1)

      Text(buddy.diveCountLabel)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.accent)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
  }

  private var shareButton: some View {
    Text(DiveTripPresentation.shareTripButtonTitle)
      .font(.caption.weight(.semibold))
      .foregroundStyle(AppTheme.Colors.headerChromeIconForeground)
      .frame(maxWidth: .infinity)
      .frame(height: 40)
      .background {
        Capsule()
          .fill(AppTheme.Colors.surfaceElevated.opacity(0.95))
      }
      .overlay {
        if highlightsShareButton {
          Capsule()
            .stroke(AppTheme.Colors.accentDeep, lineWidth: 2)
        }
      }
      .scaleEffect(highlightsShareButton ? 1.04 : 1)
  }

  // MARK: - Share preview

  private func sharePreviewScene(metrics: DemoMetrics) -> some View {
    ZStack {
      AppOverviewSheetPanelBackground()
        .ignoresSafeArea()

      #if canImport(UIKit)
      if let shareCardPreviewImage {
        Image(uiImage: shareCardPreviewImage)
          .resizable()
          .scaledToFit()
          .frame(width: metrics.shareCardFitSize.width, height: metrics.shareCardFitSize.height)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .accessibilityIdentifier("OnboardingShareWithFriendsDemo.SharePreview")
      }
      #else
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(AppTheme.Colors.surfaceElevated)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      #endif
    }
    .frame(width: metrics.phoneSize.width, height: metrics.phoneSize.height)
  }

  // MARK: - Timeline

  private func scheduleShareCardPreviewWarmup() {
    #if canImport(UIKit)
    guard shareCardPreviewImage == nil else { return }
    Task { @MainActor in
      await Task.yield()
      guard shareCardPreviewImage == nil else { return }
      shareCardPreviewImage = OnboardingShareWithFriendsDemoFixtures.renderShareCardPreviewImage()
    }
    #endif
  }

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
    screen = .tripDetail
    selectedPage = .stats
    highlightsShareButton = false
  }

  @MainActor
  private func runDemoCycle() async {
    resetDemoState()
    guard !Task.isCancelled else { return }

    try? await Task.sleep(for: .milliseconds(900))
    guard !Task.isCancelled else { return }

    withAnimation(.easeInOut(duration: 0.55)) {
      selectedPage = .sites
    }
    try? await Task.sleep(for: .milliseconds(1500))
    guard !Task.isCancelled else { return }

    withAnimation(.easeInOut(duration: 0.55)) {
      selectedPage = .buddies
    }
    try? await Task.sleep(for: .milliseconds(1100))
    guard !Task.isCancelled else { return }

    withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
      highlightsShareButton = true
    }
    try? await Task.sleep(for: .milliseconds(700))
    guard !Task.isCancelled else { return }

    withAnimation(.easeInOut(duration: 0.42)) {
      screen = .sharePreview
      highlightsShareButton = false
    }
    try? await Task.sleep(for: .milliseconds(2600))
  }
}

// MARK: - Compact stats grid

private struct OnboardingTripDemoStatsGrid: View {
  let tiles: [DiveTripStatTile]
  let tileHeight: CGFloat
  let gridSpacing: CGFloat

  private var columns: [GridItem] {
    [
      GridItem(.flexible(), spacing: gridSpacing),
      GridItem(.flexible(), spacing: gridSpacing),
    ]
  }

  var body: some View {
    LazyVGrid(columns: columns, spacing: gridSpacing) {
      ForEach(tiles) { tile in
        OnboardingTripDemoStatTile(tile: tile, tileHeight: tileHeight)
      }
    }
    .frame(
      height: OnboardingShareWithFriendsDemoLayout.statsGridHeight(
        tileHeight: tileHeight,
        spacing: gridSpacing,
        tileCount: tiles.count
      )
    )
    .frame(maxWidth: .infinity)
    .accessibilityIdentifier("TripDetail.Stats")
  }
}

private struct OnboardingTripDemoStatTile: View {
  let tile: DiveTripStatTile
  let tileHeight: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: tile.systemImage)
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(AppTheme.Colors.accent)

        Text(tile.title)
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(AppTheme.Colors.secondaryText)
          .lineLimit(1)
          .minimumScaleFactor(0.8)

        Spacer(minLength: 0)
      }

      Text(tile.value)
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)

      if !tile.footnote.isEmpty {
        Text(tile.footnote)
          .font(.caption2)
          .foregroundStyle(AppTheme.Colors.mutedText)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .frame(height: tileHeight, alignment: .topLeading)
    .appHighlightTileChrome()
  }
}

#Preview {
  OnboardingShareWithFriendsDemoView(isActive: true)
    .padding()
    .background(AppTheme.Colors.surface)
}
