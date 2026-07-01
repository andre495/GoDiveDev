import SwiftUI

/// Field Guide hub top bar — add species only (search lives in the root tab search morph).
struct FieldGuideTopChrome: View {
    let statusBarSafeAreaTop: CGFloat
    let onAddSpecies: () -> Void

    var body: some View {
        GlassEffectContainer {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                Spacer(minLength: 0)
                FieldGuideMarineLifeAddToolbarButton(action: onAddSpecies)
            }
            .appGlassChromeControlRowHeight()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .appTopChromeVerticalPadding()
        .fixedSize(horizontal: false, vertical: true)
        .background(alignment: .top) {
            if statusBarSafeAreaTop > 0.5 {
                AppStatusBarEdgeScrim(safeAreaTop: statusBarSafeAreaTop)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: AppHeaderMetrics.HeightKey.self, value: proxy.size.height)
            }
        }
    }
}
