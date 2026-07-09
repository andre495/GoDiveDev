import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Scripted equipment locker list → Garmin Mk3i detail → service section for onboarding.
struct OnboardingMonitorEquipmentDemoView: View {
  let isActive: Bool
  var maxPhoneHeight: CGFloat = OnboardingDemoPhoneFrameMetrics.defaultMaxHeight

  @State private var screen: Screen = .locker
  @State private var highlightedRowID: UUID?
  @State private var lockerScrollTargetID: UUID?
  @State private var detailScrollTargetID: String?
  @State private var demoTask: Task<Void, Never>?

  private enum Screen {
    case locker
    case detail
  }

  private enum Layout {
    static let statusBarInset: CGFloat = 54
    static let lockerHeaderHeight: CGFloat = 56
    static let heroHeight = OnboardingMonitorEquipmentDemoFixtures.heroHeight
    static let panelOverlap = OnboardingMonitorEquipmentDemoFixtures.panelOverlap
    static let pinnedSummaryHeight: CGFloat = 72
    static let rowThumbnailExtent: CGFloat = 48
  }

  var body: some View {
    OnboardingDemoPhoneFrame(maxHeight: maxPhoneHeight) {
      ZStack {
        switch screen {
        case .locker:
          lockerScene
            .transition(
              .asymmetric(
                insertion: .opacity,
                removal: .move(edge: .leading).combined(with: .opacity)
              )
            )
        case .detail:
          detailScene
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

  // MARK: - Locker

  private var lockerScene: some View {
    VStack(spacing: 0) {
      Color.clear
        .frame(height: Layout.statusBarInset)
        .accessibilityHidden(true)

      lockerHeader

      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: AppTheme.Spacing.sm) {
            ForEach(OnboardingMonitorEquipmentDemoFixtures.lockerRows) { row in
              lockerRow(row)
                .id(row.id)
            }
          }
          .padding(.horizontal, AppTheme.Spacing.md)
          .padding(.vertical, AppTheme.Spacing.sm)
        }
        .scrollIndicators(.hidden)
        .onChange(of: lockerScrollTargetID) { _, targetID in
          guard let targetID else { return }
          withAnimation(.easeInOut(duration: 1.0)) {
            proxy.scrollTo(targetID, anchor: .center)
          }
        }
      }
    }
  }

  private var lockerHeader: some View {
    HStack(spacing: AppTheme.Spacing.sm) {
      Image(systemName: "chevron.left")
        .appToolbarIconButtonLabel()
        .frame(width: 44, height: 44)
        .background {
          Circle()
            .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
        }

      Text("Equipment Locker")
        .font(.title2.weight(.bold))
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .lineLimit(1)

      Spacer(minLength: 0)

      Image(systemName: "plus")
        .appToolbarIconButtonLabel()
        .frame(width: 44, height: 44)
        .background {
          Circle()
            .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
        }
    }
    .padding(.horizontal, AppTheme.Spacing.md)
    .frame(height: Layout.lockerHeaderHeight)
    .background(AppTheme.Colors.surface.opacity(0.96))
  }

  private func lockerRow(_ row: OnboardingEquipmentDemoListRow) -> some View {
    let isHighlighted = highlightedRowID == row.id
    let title = OnboardingMonitorEquipmentDemoFixtures.displayTitle(for: row)

    return HStack(spacing: AppTheme.Spacing.md) {
      lockerRowThumbnail(row)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.body.weight(.semibold))
          .foregroundStyle(AppTheme.Colors.textPrimary)
          .lineLimit(2)

        Text(row.gearTypeLabel)
          .font(.subheadline)
          .foregroundStyle(AppTheme.Colors.secondaryText)
      }

      Spacer(minLength: 0)
    }
    .padding(AppTheme.Spacing.md)
    .background {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(AppTheme.Colors.surfaceElevated)
    }
    .overlay {
      if isHighlighted {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(AppTheme.Colors.accentDeep, lineWidth: 2)
      }
    }
    .scaleEffect(isHighlighted ? 1.02 : 1)
  }

  @ViewBuilder
  private func lockerRowThumbnail(_ row: OnboardingEquipmentDemoListRow) -> some View {
    #if canImport(UIKit)
    if let data = OnboardingMonitorEquipmentDemoFixtures.equipmentPhotoData(for: row),
       let image = UIImage(data: data) {
      Image(uiImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: Layout.rowThumbnailExtent, height: Layout.rowThumbnailExtent)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    } else {
      lockerRowThumbnailPlaceholder
    }
    #else
    lockerRowThumbnailPlaceholder
    #endif
  }

  private var lockerRowThumbnailPlaceholder: some View {
    Image(systemName: "archivebox.fill")
      .font(.title3)
      .foregroundStyle(AppTheme.Colors.accent)
      .frame(width: Layout.rowThumbnailExtent, height: Layout.rowThumbnailExtent)
      .background(AppTheme.Colors.surfaceMuted.opacity(0.5))
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }

  // MARK: - Detail

  private var detailScene: some View {
    ZStack(alignment: .top) {
      VStack(spacing: 0) {
        detailHero
        detailBlueSheetPanel
      }

      VStack(spacing: 0) {
        Color.clear
          .frame(height: Layout.statusBarInset)
          .accessibilityHidden(true)

        detailTopChrome
        Spacer(minLength: 0)
      }
    }
  }

  private var detailHero: some View {
    ZStack {
      #if canImport(UIKit)
      if let image = OnboardingMonitorEquipmentDemoFixtures.garminMk3iHeroImage {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .clipped()
      } else {
        detailHeroPlaceholder
      }
      #else
      detailHeroPlaceholder
      #endif
    }
    .frame(height: Layout.heroHeight)
    .frame(maxWidth: .infinity)
  }

  private var detailHeroPlaceholder: some View {
    LinearGradient(
      colors: [
        Color(red: 0.07, green: 0.16, blue: 0.24),
        Color(red: 0.12, green: 0.28, blue: 0.38),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .overlay {
      Image(systemName: "applewatch")
        .font(.system(size: 72, weight: .semibold))
        .foregroundStyle(.white.opacity(0.22))
    }
  }

  private var detailTopChrome: some View {
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

  private var detailBlueSheetPanel: some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
      BlueSheetPinnedSummary(
        accent: nil,
        accentColor: AppTheme.Colors.accent,
        title: OnboardingMonitorEquipmentDemoFixtures.garminTitle,
        subtitle: OnboardingMonitorEquipmentDemoFixtures.garminGearTypeLabel,
        accessibilityIdentifier: "OnboardingMonitorEquipmentDemo.TitleBlock"
      )
      .frame(height: Layout.pinnedSummaryHeight, alignment: .top)

      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            detailSection(title: "Equipment") {
              detailRow(label: "Manufacturer", value: OnboardingMonitorEquipmentDemoFixtures.garminManufacturer)
              detailRow(label: "Model", value: OnboardingMonitorEquipmentDemoFixtures.garminModel)
              detailRow(
                label: "Gear type",
                value: OnboardingMonitorEquipmentDemoFixtures.garminGearTypeLabel
              )
            }

            detailSection(title: "Status") {
              detailRow(label: "Dives used on", value: "24 dives")
              detailRow(label: "Retired", value: "No")
              detailRow(label: "Auto-add on new dives", value: "Yes")
            }

            detailSection(title: "Purchase") {
              detailRow(label: "Purchase date", value: "Mar 15, 2024")
              detailRow(label: "Shop", value: "Dive Shop Belize")
              detailRow(label: "Price", value: "1299.99")
            }

            detailSection(title: "Service") {
              detailRow(
                label: "Next service",
                value: OnboardingMonitorEquipmentDemoFixtures.nextServiceLabel
              )
              detailRow(
                label: "Last service",
                value: OnboardingMonitorEquipmentDemoFixtures.lastServiceLabel
              )
              detailRow(
                label: "Recurrence",
                value: OnboardingMonitorEquipmentDemoFixtures.recurrenceLabel
              )
              detailRow(
                label: "Service notes",
                value: OnboardingMonitorEquipmentDemoFixtures.serviceNotes
              )
            }
            .id(OnboardingMonitorEquipmentDemoFixtures.serviceSectionScrollID)

            detailSection(title: "Notes") {
              detailRow(label: "Notes", value: "Primary dive computer for Belize trips.")
            }
          }
          .padding(.top, AppTheme.Spacing.sm)
          .padding(.bottom, AppTheme.Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .onChange(of: detailScrollTargetID) { _, targetID in
          guard targetID == OnboardingMonitorEquipmentDemoFixtures.serviceSectionScrollID else { return }
          withAnimation(.easeInOut(duration: 1.15)) {
            proxy.scrollTo(targetID, anchor: .top)
          }
        }
      }
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

  private func detailSection(title: String, @ViewBuilder content: () -> some View) -> some View {
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
        .fixedSize(horizontal: false, vertical: true)
    }
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
    screen = .locker
    highlightedRowID = nil
    lockerScrollTargetID = nil
    detailScrollTargetID = nil
  }

  @MainActor
  private func runDemoCycle() async {
    resetDemoState()
    guard !Task.isCancelled else { return }

    try? await Task.sleep(for: .milliseconds(900))
    guard !Task.isCancelled else { return }

    lockerScrollTargetID = OnboardingMonitorEquipmentDemoFixtures.focusedItemID
    try? await Task.sleep(for: .milliseconds(900))
    guard !Task.isCancelled else { return }

    withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
      highlightedRowID = OnboardingMonitorEquipmentDemoFixtures.focusedItemID
    }
    try? await Task.sleep(for: .milliseconds(700))
    guard !Task.isCancelled else { return }

    withAnimation(.easeInOut(duration: 0.42)) {
      screen = .detail
      highlightedRowID = nil
    }
    try? await Task.sleep(for: .milliseconds(1100))
    guard !Task.isCancelled else { return }

    detailScrollTargetID = OnboardingMonitorEquipmentDemoFixtures.serviceSectionScrollID
    try? await Task.sleep(for: .milliseconds(2800))
  }
}

#Preview {
  OnboardingMonitorEquipmentDemoView(isActive: true)
    .padding()
    .background(AppTheme.Colors.surface)
}
