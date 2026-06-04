import SwiftUI

enum AppHeaderMetrics {
    /// Measured height of **`AppHeader`** / logbook **top scroll chrome** (no title row) — use an **in‑scroll spacer** (not outer **`padding`**) so rows extend under the bar.
    enum HeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }
}

// MARK: - Status bar scrim (narrow band only)

/// Short fade at the **very top** of the screen so status content reads on busy backgrounds; uses a **dark** feather in both color schemes (not light **`surfaceElevated`**).
struct AppStatusBarEdgeScrim: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// **Window** safe-area top (from an outer **`GeometryReader`**, e.g. Logbook root).
    let safeAreaTop: CGFloat

    /// Feather **below** the safe top into the page gradient.
    private var feather: CGFloat { 22 }

    private var bandHeight: CGFloat { max(0, safeAreaTop) + feather }

    var body: some View {
        Group {
            if reduceTransparency {
                AppTheme.Colors.statusBarEdgeScrimSolid
                    .frame(height: max(0, safeAreaTop) + 8)
            } else {
                AppTheme.Colors.statusBarEdgeScrimGradient
                    .frame(height: bandHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct AppHeader<TrailingContent: View>: View {
    private let appName = "GoDive"
    let title: String
    let showsBackButton: Bool
    /// When **`false`**, the **GoDive** wordmark is hidden. A non-empty **`title`** is shown centered instead (Field Guide species, category, etc.).
    let showsBrandWordmark: Bool
    let trailingContent: TrailingContent
    /// Pass **`GeometryReader.safeAreaInsets.top`** from the tab / page root so the status scrim matches the device inset.
    let statusBarSafeAreaTop: CGFloat

    init(
        title: String,
        showsBackButton: Bool = false,
        showsBrandWordmark: Bool = true,
        statusBarSafeAreaTop: CGFloat = 0,
        @ViewBuilder trailingContent: () -> TrailingContent
    ) {
        self.title = title
        self.showsBackButton = showsBackButton
        self.showsBrandWordmark = showsBrandWordmark
        self.statusBarSafeAreaTop = statusBarSafeAreaTop
        self.trailingContent = trailingContent()
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.sm) {
                if showsBackButton {
                    SecondaryDestinationBackButton()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if showsBrandWordmark {
                    Text(appName)
                        .font(AppTheme.Typography.headerBrandTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.Colors.headerTitleForegroundGradient)
                } else if !title.isEmpty {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                } else {
                    Color.clear
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .allowsTightening(true)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(showsBrandWordmark ? appName : title)
            .accessibilityHidden(!showsBrandWordmark && title.isEmpty)

            HStack(spacing: AppTheme.Spacing.sm) {
                trailingContent
                    .foregroundStyle(AppTheme.Colors.iconPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
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

extension AppHeader where TrailingContent == EmptyView {
    init(
        title: String,
        showsBackButton: Bool = false,
        showsBrandWordmark: Bool = true,
        statusBarSafeAreaTop: CGFloat = 0
    ) {
        self.init(
            title: title,
            showsBackButton: showsBackButton,
            showsBrandWordmark: showsBrandWordmark,
            statusBarSafeAreaTop: statusBarSafeAreaTop
        ) {
            EmptyView()
        }
    }
}

#Preview {
    AppHeader(title: "Home", statusBarSafeAreaTop: 54)
        .background(AppTheme.Colors.screenBackgroundGradient)
}
