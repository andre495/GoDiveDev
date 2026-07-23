import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Interactive duplicate of profile / buddy / friend **BlueSheetDetailPage** identity chrome — drag handles, read deltas.
///
/// **Settings → Design lab (temporary)** — DEBUG builds only.
struct BlueSheetIdentityLayoutTuningView: View {
    @Environment(AccountSession.self) private var accountSession

    @State private var deltas = BlueSheetIdentityLayoutTuningPresentation.loadPersistedDeltas()
    @State private var avatarDragOrigin = BlueSheetIdentityLayoutTuningPresentation.Deltas()
    @State private var nameDragOriginY: CGFloat = 0
    @State private var dividerDragOriginY: CGFloat = 0
    @State private var panelContentDragOriginY: CGFloat = 0
    @State private var showsCopiedConfirmation = false
    @State private var usesProfileBubblePanel = true

    private enum Layout {
        static let avatarDiameter = DiveBuddyDetailPresentation.profileAvatarDiameter
        static let avatarOverlapOffset = DiveBuddyDetailPresentation.avatarOverlapOffset()
    }

    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var layoutSafeAreaTopFloor =
        DiveBuddyDetailPresentation.initialPushedLayoutSafeAreaTopFloor()
    @State private var layoutViewportHeightFloor =
        DiveBuddyDetailPresentation.initialPushedLayoutViewportFloor()

    private var displayName: String {
        accountSession.currentProfile?.displayName ?? "Jamie Rivera"
    }

    private var diveCountLabel: String {
        ProfilePresentation.diveActivityCountLabel(42)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppHeaderlessPage {
                BlueSheetPageShell(
                    configuration: .pushedDetail(
                        accessibilityRootIdentifier: "BlueSheetIdentityTuning.Root",
                        usesProfileBubblePanelBackground: usesProfileBubblePanel
                    ),
                    seamInputs: HomeOverviewPushedLayoutPresentation.pushedPageSeamInputs(),
                    layoutMode: .pushedDetail(transitionViewportHeightFloor: layoutViewportHeightFloor),
                    embedTopChromeInLayout: true,
                    appliesPushedLayoutState: true,
                    onLayoutResolved: nil,
                    headerClearance: $headerClearance,
                    layoutSafeAreaTopFloor: $layoutSafeAreaTopFloor,
                    layoutViewportHeightFloor: $layoutViewportHeightFloor,
                    hero: { context in
                        tuningHero(context: context)
                    },
                    heroOverlay: { _ in EmptyView() },
                    panelOverlay: {
                        tuningAvatarOverlay
                    },
                    panel: { layout in
                        tuningPanelBody(layout: layout)
                    },
                    topChrome: { safeTop, topInset, _ in
                        tuningTopChrome(safeTop: safeTop, topInset: topInset)
                    },
                    floatingChrome: { _, _, _ in EmptyView() }
                )
            }
            .ignoresSafeArea(edges: [.horizontal])

            tuningHUD
        }
        .hidesBottomTabBarWhenPushed()
        .onChange(of: deltas) { _, newValue in
            BlueSheetIdentityLayoutTuningPresentation.persist(newValue)
        }
        .onAppear {
            avatarDragOrigin = deltas
            nameDragOriginY = deltas.identityTextVertical
            dividerDragOriginY = deltas.panelDividerVertical
            panelContentDragOriginY = deltas.panelContentTop
        }
        .alert("Copied", isPresented: $showsCopiedConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Delta summary is on the pasteboard.")
        }
    }

    private func tuningTopChrome(safeTop: CGFloat, topInset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            BlueSheetTopChromeFadeLayer(
                safeTop: safeTop,
                topInset: topInset,
                style: .detailTop
            )
            AppHeader(
                title: "Identity layout",
                showsBackButton: true,
                showsBrandWordmark: false,
                statusBarSafeAreaTop: safeTop,
                statusBarUsesListChromeFeather: BlueSheetTopChromePresentation.DetailTopFade.usesListStatusBarScrim
            )
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private func tuningHero(context: BlueSheetHeaderPageLayoutContext) -> some View {
        BlueSheetDetailHeroBandFill(accessibilityIdentifier: "BlueSheetIdentityTuning.HeroBand") {
            ZStack {
                LinearGradient(
                    colors: [
                        AppTheme.Colors.accent.opacity(0.35),
                        AppTheme.Colors.accentDeep.opacity(0.55),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var tuningAvatarOverlay: some View {
        ProfileAvatarView(
            profilePhoto: accountSession.currentProfile?.profilePhoto,
            diameter: Layout.avatarDiameter,
            iconFont: .system(size: 56),
            placeholderInitials: DiveBuddyPresentation.initials(from: displayName)
        )
        .padding(
            .leading,
            DiveBuddyDetailPresentation.avatarLeadingInset + deltas.avatarLeading
        )
        .offset(
            y: -Layout.avatarOverlapOffset
                + deltas.avatarVertical
        )
        .overlay(alignment: .topLeading) {
            tuningDragBadge("Avatar", color: .orange)
                .offset(x: Layout.avatarDiameter - 8, y: -8)
        }
        .gesture(avatarDragGesture)
        .accessibilityIdentifier("BlueSheetIdentityTuning.Avatar")
    }

    private var tuningPinnedSummary: some View {
        BlueSheetPinnedSummary(
            accent: diveCountLabel,
            accentFont: BlueSheetPinnedSummaryPresentation.buddyAccentFont,
            title: displayName,
            titleFont: BlueSheetPinnedSummaryPresentation.buddyTitleFont,
            titleLineLimit: 2,
            titleMinimumScaleFactor: 0.85,
            usesLeadingAccessoryLayout: true,
            contentVerticalOffset:
                -DiveBuddyDetailPresentation.identityTextLift
                + deltas.identityTextVertical,
            leadingAccessory: {
                Color.clear
                    .frame(
                        width: Layout.avatarDiameter,
                        height: Layout.avatarOverlapOffset
                    )
                    .accessibilityHidden(true)
            }
        )
        .overlay(alignment: .topTrailing) {
            tuningDragBadge("Name", color: .cyan)
        }
        .gesture(nameDragGesture)
    }

    @ViewBuilder
    private func tuningPanelBody(layout: BlueSheetHeaderPageLayoutContext) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            tuningPinnedSummary
                .padding(.top, BlueSheetDetailPagePinnedSummaryPresentation.seamTopPadding)
                .padding(
                    .bottom,
                    BlueSheetDetailPagePinnedSummaryPresentation.bodyBottomPadding
                        + BlueSheetDetailPagePinnedSummaryPresentation.panelContentTopDividerVerticalAdjustment
                        + deltas.panelDividerVertical
                )

            tuningPanelContentDivider

            tuningPlaceholderPanelContent(bottomInset: layout.bottomScrollInset)
                .padding(
                    .top,
                    BlueSheetDetailPagePinnedSummaryPresentation.bodyBottomPadding
                        + deltas.panelContentTop
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, BlueSheetDetailPagePinnedSummaryPresentation.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var tuningPanelContentDivider: some View {
        ZStack(alignment: .trailing) {
            BlueSheetDetailPanelContentTopDivider()

            tuningDragBadge("Divider", color: .yellow)
                .offset(y: -18)
        }
        .frame(height: 32)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(dividerDragGesture)
        .accessibilityIdentifier("BlueSheetIdentityTuning.PanelDivider")
    }

    private func tuningPlaceholderPanelContent(bottomInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Panel content (pager / tabs)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .overlay(alignment: .topTrailing) {
                    tuningDragBadge("Content top", color: .mint)
                        .offset(y: -22)
                }
                .gesture(panelContentDragGesture)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated.opacity(0.6))
                .frame(height: 120)
                .overlay {
                    Text("Placeholder body")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
        }
        .padding(.bottom, bottomInset)
    }

    private var tuningHUD: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Profile bubble panel", isOn: $usesProfileBubblePanel)
                .font(.caption.weight(.semibold))
                .tint(AppTheme.Colors.accent)

            Group {
                deltaLine("avatarLeading", deltas.avatarLeading)
                deltaLine("avatarVertical", deltas.avatarVertical)
                deltaLine("identityTextVertical", deltas.identityTextVertical)
                deltaLine("panelDividerVertical", deltas.panelDividerVertical)
                deltaLine("panelContentTop", deltas.panelContentTop)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white)

            HStack(spacing: AppTheme.Spacing.sm) {
                Button("Reset") {
                    deltas = .init()
                    avatarDragOrigin = .init()
                    nameDragOriginY = 0
                    dividerDragOriginY = 0
                    panelContentDragOriginY = 0
                }
                .buttonStyle(.bordered)

                Button("Copy deltas") {
                    copyDeltasToPasteboard()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.md)
    }

    private func deltaLine(_ label: String, _ value: CGFloat) -> some View {
        Text("\(label): \(signedPt(value))")
    }

    private func signedPt(_ value: CGFloat) -> String {
        String(format: "%+.1f pt", Double(value))
    }

    private func tuningDragBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.95), in: Capsule())
    }

    private var avatarDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                deltas.avatarLeading = avatarDragOrigin.avatarLeading + value.translation.width
                deltas.avatarVertical = avatarDragOrigin.avatarVertical + value.translation.height
            }
            .onEnded { _ in
                avatarDragOrigin = deltas
            }
    }

    private var nameDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                deltas.identityTextVertical = nameDragOriginY + value.translation.height
            }
            .onEnded { _ in
                nameDragOriginY = deltas.identityTextVertical
            }
    }

    private var dividerDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                deltas.panelDividerVertical = dividerDragOriginY + value.translation.height
            }
            .onEnded { _ in
                dividerDragOriginY = deltas.panelDividerVertical
            }
    }

    private var panelContentDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                deltas.panelContentTop = panelContentDragOriginY + value.translation.height
            }
            .onEnded { _ in
                panelContentDragOriginY = deltas.panelContentTop
            }
    }

    private func copyDeltasToPasteboard() {
        let text = BlueSheetIdentityLayoutTuningPresentation.handoffSummary(deltas: deltas)
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
        showsCopiedConfirmation = true
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        BlueSheetIdentityLayoutTuningView()
    }
    .environment(AccountSession.shared)
}
#endif
