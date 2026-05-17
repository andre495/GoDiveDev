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

/// Short fade at the **very top** of the screen so status content reads on busy backgrounds; **does not** tint the main header / toolbar row (that row stays visually continuous with **`screenBackgroundGradient`**).
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
                AppTheme.Colors.surfaceElevated
                    .opacity(0.96)
                    .frame(height: max(0, safeAreaTop) + 8)
            } else {
                LinearGradient(
                    stops: [
                        .init(color: AppTheme.Colors.surfaceElevated.opacity(0.88), location: 0.0),
                        .init(color: AppTheme.Colors.surfaceGradientTop.opacity(0.35), location: 0.62),
                        .init(color: Color.clear, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: bandHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct AppHeader<TrailingContent: View>: View {
    @Environment(\.dismiss) private var dismiss

    private let appName = "GoDive"
    let title: String
    let showsBackButton: Bool
    /// When **`false`**, the **GoDive** wordmark is hidden (e.g. Logbook **+** row) but layout matches Home so the status scrim composites identically.
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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.Colors.iconPrimary)
                    .accessibilityLabel("Back")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(appName)
                .font(AppTheme.Typography.headerBrandTitle)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.Colors.headerTitleForegroundGradient)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .allowsTightening(true)
                .opacity(showsBrandWordmark ? 1 : 0)
                .accessibilityHidden(!showsBrandWordmark)

            HStack(spacing: AppTheme.Spacing.sm) {
                trailingContent
                    .foregroundStyle(AppTheme.Colors.iconPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
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
