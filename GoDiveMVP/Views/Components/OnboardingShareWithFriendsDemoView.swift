import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Scripted trip detail pager → share card preview for onboarding.
struct OnboardingShareWithFriendsDemoView: View {
  let isActive: Bool
  var maxPhoneHeight: CGFloat = OnboardingDemoPhoneFrameMetrics.defaultMaxHeight

  @State private var screen: Screen = .tripDetail
  @State private var selectedPage = OnboardingShareWithFriendsDemoFixtures.DemoPage.stats
  @State private var highlightsShareButton = false
  @State private var demoTask: Task<Void, Never>?

  private enum Screen {
    case tripDetail
    case sharePreview
  }

  private typealias DemoPage = OnboardingShareWithFriendsDemoFixtures.DemoPage

  private enum Layout {
    static let statusBarInset: CGFloat = 54
    static let heroHeight = OnboardingShareWithFriendsDemoFixtures.heroHeight
    static let panelOverlap = OnboardingShareWithFriendsDemoFixtures.panelOverlap
    static let pinnedSummaryHeight: CGFloat = 68
    static let demoBuddyAvatarDiameter = OnboardingShareWithFriendsDemoFixtures.buddyAvatarDiameter
  }

  private var shareCardPreviewScale: CGFloat {
    OnboardingShareWithFriendsDemoFixtures.shareCardScaleForPhoneFrame()
  }

  private var phoneLogicalSize: CGSize {
    OnboardingDemoPhoneFrameMetrics.referenceLogicalSize
  }

  var body: some View {
    OnboardingDemoPhoneFrame(maxHeight: maxPhoneHeight) {
      ZStack {
        switch screen {
        case .tripDetail:
          tripDetailScene
            .transition(
              .asymmetric(
                insertion: .opacity,
                removal: .move(edge: .leading).combined(with: .opacity)
              )
            )
        case .sharePreview:
          sharePreviewScene
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

  // MARK: - Trip detail

  private var tripDetailScene: some View {
    ZStack(alignment: .top) {
      VStack(spacing: 0) {
        tripHero
        tripBlueSheetPanel
      }

      VStack(spacing: 0) {
        Color.clear
          .frame(height: Layout.statusBarInset)
          .accessibilityHidden(true)

        tripTopChrome
        Spacer(minLength: 0)
      }
    }
  }

  private var tripHero: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.05, green: 0.22, blue: 0.38),
          Color(red: 0.12, green: 0.42, blue: 0.55),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      Image(systemName: "airplane.departure")
        .font(.system(size: 64, weight: .semibold))
        .foregroundStyle(.white.opacity(0.22))
        .offset(y: 24)
    }
    .frame(height: Layout.heroHeight)
    .frame(maxWidth: .infinity)
  }

  private var tripTopChrome: some View {
    HStack(spacing: AppTheme.Spacing.sm) {
      Image(systemName: "chevron.left")
        .appToolbarIconButtonLabel()
        .frame(width: 44, height: 44)
        .background {
          Circle()
            .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
        }

      Spacer(minLength: 0)

      Text("Edit")
        .font(.body.weight(.semibold))
        .padding(.horizontal, AppTheme.Spacing.sm)
        .frame(height: 44)
        .background {
          Capsule()
            .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
        }
    }
    .padding(.horizontal, AppTheme.Spacing.md)
    .padding(.top, AppTheme.Spacing.sm)
  }

  private var tripBlueSheetPanel: some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
      tripPinnedSummary
      tripPager
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

  private var tripPinnedSummary: some View {
    BlueSheetPinnedSummary(
      accent: OnboardingShareWithFriendsDemoFixtures.tripDateRange,
      accentColor: AppTheme.Colors.accent,
      title: OnboardingShareWithFriendsDemoFixtures.tripTitle,
      accessibilityIdentifier: "OnboardingShareWithFriendsDemo.TripTitle"
    )
    .frame(height: Layout.pinnedSummaryHeight, alignment: .top)
  }

  private var tripPager: some View {
    TabView(selection: $selectedPage) {
      ForEach(OnboardingShareWithFriendsDemoFixtures.demoPages) { page in
        pagerPageContent(for: page)
          .tag(page)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: .automatic))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private func pagerPageContent(for page: DemoPage) -> some View {
    switch page {
    case .stats:
      TripDetailTripStatsSection(tiles: OnboardingShareWithFriendsDemoFixtures.statTiles)
        .padding(.top, AppTheme.Spacing.sm)
    case .sites:
      demoSitesPage
    case .buddies:
      demoBuddiesPage
    }
  }

  private var demoSitesPage: some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
      Text("3 planned sites")
        .font(.subheadline)
        .foregroundStyle(AppTheme.Colors.secondaryText)

      ForEach(OnboardingShareWithFriendsDemoFixtures.plannedSiteRows) { row in
        demoSiteRow(row)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func demoSiteRow(_ row: OnboardingTripDemoSiteRow) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(row.displayName)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .lineLimit(1)

      Text(row.coordinateLine)
        .font(.caption)
        .foregroundStyle(AppTheme.Colors.secondaryText)
        .lineLimit(1)

      Text(row.placeLine)
        .font(.caption)
        .foregroundStyle(AppTheme.Colors.secondaryText)
        .lineLimit(1)
    }
    .padding(AppTheme.Spacing.sm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(AppTheme.Colors.surfaceElevated)
    }
  }

  private var demoBuddiesPage: some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
      let columns = Array(
        repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.sm),
        count: 3
      )

      LazyVGrid(columns: columns, alignment: .center, spacing: AppTheme.Spacing.sm) {
        ForEach(OnboardingShareWithFriendsDemoFixtures.taggedBuddies) { buddy in
          demoBuddyCell(buddy)
        }
      }

      Spacer(minLength: 0)

      shareButton
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private func demoBuddyCell(_ buddy: OnboardingTripDemoBuddy) -> some View {
    VStack(spacing: 6) {
      ProfileAvatarView(
        profilePhoto: OnboardingShareWithFriendsDemoFixtures.profilePhotoData(for: buddy),
        diameter: Layout.demoBuddyAvatarDiameter,
        iconFont: .body,
        placeholderInitials: DiveBuddyPresentation.initials(from: buddy.displayName)
      )

      Text(buddy.displayName)
        .font(.caption.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .lineLimit(1)

      Text(buddy.diveCountLabel)
        .font(.caption.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.accent)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
  }

  private var shareButton: some View {
    Text(DiveTripPresentation.shareTripButtonTitle)
      .font(.body.weight(.semibold))
      .foregroundStyle(AppTheme.Colors.headerChromeIconForeground)
      .frame(maxWidth: .infinity)
      .frame(height: 44)
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

  private var sharePreviewScene: some View {
    ZStack(alignment: .top) {
      AppOverviewSheetPanelBackground()
        .ignoresSafeArea()

      shareCardPreview
        .frame(width: phoneLogicalSize.width, height: phoneLogicalSize.height, alignment: .top)
        .clipped()
    }
  }

  @ViewBuilder
  private var shareCardPreview: some View {
    #if canImport(UIKit)
    TripShareCardView(
      tripTitle: OnboardingShareWithFriendsDemoFixtures.tripTitle,
      dateRange: OnboardingShareWithFriendsDemoFixtures.tripDateRange,
      members: OnboardingShareWithFriendsDemoFixtures.shareCardMembers,
      marineLifeCallout: OnboardingShareWithFriendsDemoFixtures.marineLifeCallout,
      mapImage: OnboardingShareWithFriendsDemoFixtures.shareCardMapImage
    )
    .frame(width: TripShareCardPresentation.cardWidth, alignment: .top)
    .frame(minHeight: TripShareCardPresentation.cardMinHeight, alignment: .top)
    .background(AppOverviewSheetPanelBackground())
    .scaleEffect(shareCardPreviewScale, anchor: .top)
    .frame(
      width: TripShareCardPresentation.cardWidth * shareCardPreviewScale,
      height: TripShareCardPresentation.cardMinHeight * shareCardPreviewScale,
      alignment: .top
    )
    #else
    RoundedRectangle(cornerRadius: 16, style: .continuous)
      .fill(AppTheme.Colors.surfaceElevated)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    #endif
  }

  // MARK: - Timeline

  private func startDemoLoop() {
    stopDemoLoop()
    resetDemoState()

    demoTask = Task { @MainActor in
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

#Preview {
  OnboardingShareWithFriendsDemoView(isActive: true)
    .padding()
    .background(AppTheme.Colors.surface)
}
