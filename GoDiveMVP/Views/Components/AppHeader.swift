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

enum AppHeaderTitlePlacement: Sendable {
    case centered
    /// Title sits in the leading cluster immediately after the back chevron (Field Guide subcategory).
    case leadingAfterBack
}

struct AppHeader<TrailingContent: View>: View {
    private let appName = "GoDive"
    let title: String
    let showsBackButton: Bool
    /// When **`false`**, the **GoDive** wordmark is hidden. A non-empty **`title`** is shown per **`titlePlacement`**.
    let showsBrandWordmark: Bool
    let titlePlacement: AppHeaderTitlePlacement
    let trailingContent: TrailingContent
    /// Pass **`GeometryReader.safeAreaInsets.top`** from the tab / page root so the status scrim matches the device inset.
    let statusBarSafeAreaTop: CGFloat

    init(
        title: String,
        showsBackButton: Bool = false,
        showsBrandWordmark: Bool = true,
        titlePlacement: AppHeaderTitlePlacement = .centered,
        statusBarSafeAreaTop: CGFloat = 0,
        @ViewBuilder trailingContent: () -> TrailingContent
    ) {
        self.title = title
        self.showsBackButton = showsBackButton
        self.showsBrandWordmark = showsBrandWordmark
        self.titlePlacement = titlePlacement
        self.statusBarSafeAreaTop = statusBarSafeAreaTop
        self.trailingContent = trailingContent()
    }

    var body: some View {
        Group {
            if usesLeadingTitlePlacement {
                leadingTitleHeaderRow
            } else {
                standardHeaderRow
            }
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

    /// Back chevron + full-width title + trailing actions (Field Guide subcategory).
    private var leadingTitleHeaderRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            if showsBackButton {
                SecondaryDestinationBackButton()
            }

            if !title.isEmpty {
                leadingHeaderTitleText
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(title)
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                trailingContent
            }
            .foregroundStyle(AppTheme.Colors.iconPrimary)
        }
    }

    private var standardHeaderRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            leadingCluster
                .frame(maxWidth: .infinity, alignment: .leading)

            centerCluster
                .frame(maxWidth: .infinity)

            HStack(spacing: AppTheme.Spacing.sm) {
                trailingContent
                    .foregroundStyle(AppTheme.Colors.iconPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var leadingCluster: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            if showsBackButton {
                SecondaryDestinationBackButton()
            }
        }
    }

    @ViewBuilder
    private var centerCluster: some View {
        Group {
            if showsBrandWordmark {
                Text(appName)
                    .font(AppTheme.Typography.headerBrandTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.Colors.headerTitleForegroundGradient)
            } else if usesCenteredTitlePlacement, !title.isEmpty {
                headerTitleText
                    .multilineTextAlignment(.center)
            } else {
                Color.clear
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .allowsTightening(true)
        .accessibilityLabel(showsBrandWordmark ? appName : title)
        .accessibilityHidden(!showsBrandWordmark && (title.isEmpty || usesLeadingTitlePlacement))
    }

    private var headerTitleText: some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
    }

    private var leadingHeaderTitleText: some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var usesLeadingTitlePlacement: Bool {
        !showsBrandWordmark && titlePlacement == .leadingAfterBack
    }

    private var usesCenteredTitlePlacement: Bool {
        !showsBrandWordmark && titlePlacement == .centered
    }
}

extension AppHeader where TrailingContent == EmptyView {
    init(
        title: String,
        showsBackButton: Bool = false,
        showsBrandWordmark: Bool = true,
        titlePlacement: AppHeaderTitlePlacement = .centered,
        statusBarSafeAreaTop: CGFloat = 0
    ) {
        self.init(
            title: title,
            showsBackButton: showsBackButton,
            showsBrandWordmark: showsBrandWordmark,
            titlePlacement: titlePlacement,
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
