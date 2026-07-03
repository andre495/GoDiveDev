import SwiftUI

/// Inline **`.largeTitle`** row — fixed-width leading / trailing controls with a centered title that compacts on scroll.
struct CollapsibleInlineTitleHeader<Leading: View, Trailing: View>: View {
    let title: String
    let isCollapsed: Bool
    let statusBarSafeAreaTop: CGFloat
    var titleAccessibilityIdentifier: String?
    var minimumTitleScaleFactor: CGFloat = CollapsibleInlineTitleHeaderPresentation.minimumTitleScaleFactor
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        GlassEffectContainer {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                leading()
                    .frame(
                        width: CollapsibleInlineTitleHeaderPresentation.sideControlWidth,
                        alignment: .leading
                    )

                Text(title)
                    .font(titleFont)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(minimumTitleScaleFactor)
                    .allowsTightening(true)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .layoutPriority(-1)
                    .accessibilityIdentifier(titleAccessibilityIdentifier ?? title)

                trailing()
                    .frame(
                        width: CollapsibleInlineTitleHeaderPresentation.sideControlWidth,
                        alignment: .trailing
                    )
            }
            .appGlassChromeControlRowHeight()
            .appHeaderChromeIconForeground()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .appTopChromeVerticalPadding()
        .fixedSize(horizontal: false, vertical: true)
        .background(alignment: .top) {
            if statusBarSafeAreaTop > 0.5 {
                AppStatusBarEdgeScrim(
                    safeAreaTop: statusBarSafeAreaTop,
                    usesListChromeFeather: true
                )
                .ignoresSafeArea(edges: .top)
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: AppHeaderMetrics.HeightKey.self, value: proxy.size.height)
            }
        }
        .animation(.snappy(duration: 0.18), value: isCollapsed)
    }

    private var titleFont: Font {
        isCollapsed
            ? .headline
            : AppTheme.Typography.headerBrandTitle
    }
}
