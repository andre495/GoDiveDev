import SwiftUI

// MARK: - Fade layer

enum BlueSheetTopChromeFadeStyle: Sendable {
    case homeHero
    case detailTop
}

/// Status-bar + optional hero fade behind blue-sheet top chrome.
struct BlueSheetTopChromeFadeLayer: View {
    let safeTop: CGFloat
    let topInset: CGFloat
    let style: BlueSheetTopChromeFadeStyle

    var body: some View {
        switch style {
        case .homeHero:
            LogbookTopChromeScrim(topObstructionHeight: topInset)
                .padding(.top, -safeTop)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
                .zIndex(0.5)
        case .detailTop:
            EmptyView()
        }
    }
}

// MARK: - Home tab root

/// GoDive header + **homeHeroFade** + trailing profile (or other actions).
struct BlueSheetHomeTopChrome<Trailing: View>: View {
    let safeTop: CGFloat
    let topInset: CGFloat
    let title: String

    @ViewBuilder var trailingContent: () -> Trailing

    var body: some View {
        ZStack(alignment: .top) {
            BlueSheetTopChromeFadeLayer(
                safeTop: safeTop,
                topInset: topInset,
                style: .homeHero
            )

            AppHeader(
                title: title,
                showsBackButton: false,
                statusBarSafeAreaTop: safeTop
            ) {
                trailingContent()
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .zIndex(1)
        }
    }
}

// MARK: - Pushed detail

/// Scalable **Edit** trailing action for detail top chrome.
struct BlueSheetDetailEditAction: View {
    var isEnabled: Bool = true
    let action: () -> Void
    let accessibilityIdentifier: String
    var accessibilityLabel: String?

    var body: some View {
        AppEditToolbarButton(
            action: action,
            accessibilityIdentifier: accessibilityIdentifier,
            accessibilityLabel: accessibilityLabel
        )
        .disabled(!isEnabled)
    }
}

/// Back + **Edit** row with **detailTopFade** (short status-bar scrim via list feather).
struct BlueSheetDetailTopChrome: View {
    let safeTop: CGFloat
    let topInset: CGFloat
    var isEditEnabled: Bool = true
    let onEdit: () -> Void
    var editAccessibilityIdentifier: String
    var editAccessibilityLabel: String?

    var body: some View {
        ZStack(alignment: .top) {
            BlueSheetTopChromeFadeLayer(
                safeTop: safeTop,
                topInset: topInset,
                style: .detailTop
            )

            AppHeader(
                title: "",
                showsBackButton: true,
                showsBrandWordmark: false,
                statusBarSafeAreaTop: safeTop,
                statusBarUsesListChromeFeather: BlueSheetTopChromePresentation.DetailTopFade.usesListStatusBarScrim
            ) {
                BlueSheetDetailEditAction(
                    isEnabled: isEditEnabled,
                    action: onEdit,
                    accessibilityIdentifier: editAccessibilityIdentifier,
                    accessibilityLabel: editAccessibilityLabel
                )
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .zIndex(1)
        }
    }
}
