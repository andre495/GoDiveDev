import SwiftUI

/// Bottom band where pushed buddy/trip scroll content meets the screen edge — matches **`AppOverviewSheetPanelBackground`** hue.
struct HomeSheetPanelBottomScrim: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let height: CGFloat

    var body: some View {
        Group {
            if reduceTransparency {
                AppOverviewSheetPanelBackground()
                    .opacity(0.98)
            } else {
                AppOverviewSheetPanelBackground()
                    .mask(bottomAnchoredFeatherMask)
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Feather grows **up** from the band bottom (opaque at bottom edge, clear at top).
    private var bottomAnchoredFeatherMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.clear, location: 0),
                .init(color: Color.black.opacity(0.32), location: 0.58),
                .init(color: Color.black, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Bottom fade band pinned to the **local** container bottom (pager page geometry — not full-screen Y).
struct HomeSheetPanelBottomScrollFadeBand: View {
    var body: some View {
        GeometryReader { geo in
            let safeAreaBottom = geo.safeAreaInsets.bottom
            let bandHeight = HomeOverviewLayout.pushedPanelBottomScrollFadeHeight(
                safeAreaBottom: safeAreaBottom
            )

            if bandHeight > 0 {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HomeSheetPanelBottomScrim(height: bandHeight)
                        .frame(height: bandHeight)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Sheet-matched bottom band over scrolling pager content; **`TabView`** page dots stay above each page.
    func homeSheetPanelBottomScrollFade() -> some View {
        overlay(alignment: .bottom) {
            HomeSheetPanelBottomScrollFadeBand()
                .padding(.horizontal, -AppTheme.Spacing.lg)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
