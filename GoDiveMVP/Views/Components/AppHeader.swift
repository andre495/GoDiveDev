import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

enum AppStatusBarEdgeScrimMetrics {
    /// Feather below the safe area on **GoDive** / **`AppHeader`** (taller than list chrome).
    static let brandHeaderFeatherHeight: CGFloat = 40
    /// Peak scrim opacity at the screen top — never fully opaque.
    static let brandHeaderMaxScrimOpacity: Double = 0.60
    /// Shorter feather for list-style top chrome (**certifications**, **buddies**, etc.).
    static let listChromeFeatherHeight: CGFloat = 22
}

/// Short fade at the **very top** of the screen so status content reads on busy backgrounds.
struct AppStatusBarEdgeScrim: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    /// **Window** safe-area top (from an outer **`GeometryReader`**, e.g. Logbook root).
    let safeAreaTop: CGFloat
    /// When **`true`**, uses **`listStatusBarEdgeScrimGradient`** (same pale ocean base as wordmark header).
    var usesListChromeFeather: Bool = false
    /// **Explore** map — deep **`surfaceGradientBottom`** fade in light mode.
    var usesExploreMapChrome: Bool = false

    private var usesLightExploreMapChrome: Bool {
        usesExploreMapChrome && colorScheme == .light
    }

    /// Feather **below** the safe top into the page gradient.
    private var feather: CGFloat {
        if usesExploreMapChrome || usesListChromeFeather {
            return AppStatusBarEdgeScrimMetrics.listChromeFeatherHeight
        }
        return AppStatusBarEdgeScrimMetrics.brandHeaderFeatherHeight
    }

    private var bandHeight: CGFloat { max(0, safeAreaTop) + feather }

    var body: some View {
        Group {
            if reduceTransparency {
                solidScrim
                    .frame(height: max(0, safeAreaTop) + 8)
            } else {
                gradientScrim
                    .frame(height: bandHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var solidScrim: some View {
        if usesLightExploreMapChrome {
            AppTheme.Colors.exploreMapStatusBarEdgeScrimSolid
        } else if usesListChromeFeather {
            AppTheme.Colors.listStatusBarEdgeScrimSolid
        } else {
            AppTheme.Colors.statusBarEdgeScrimSolid
        }
    }

    @ViewBuilder
    private var gradientScrim: some View {
        if usesLightExploreMapChrome {
            AppTheme.Colors.exploreMapStatusBarEdgeScrimGradient
        } else if usesListChromeFeather {
            AppTheme.Colors.listStatusBarEdgeScrimGradient
        } else {
            AppTheme.Colors.statusBarEdgeScrimGradient
        }
    }
}

enum AppHeaderTitlePlacement: Sendable {
    case centered
    /// Title sits in the leading cluster immediately after the back chevron (Field Guide subcategory).
    case leadingAfterBack
    /// Full-width title on its own row under the back chevron (catalog dive site overview).
    case belowBackRow
}

/// Full-width **`.title.bold`** under the back row, centered, **`textPrimary`**.
enum AppHeaderStackedTitleChrome: Sendable {
    static let titlePlacement = AppHeaderTitlePlacement.belowBackRow
    static let titleMultilineAlignment = TextAlignment.center
}

struct AppHeader<TrailingContent: View>: View {
    private let appName = "GoDive"
    let title: String
    let showsBackButton: Bool
    /// When **`false`**, the **GoDive** wordmark is hidden. A non-empty **`title`** is shown per **`titlePlacement`**.
    let showsBrandWordmark: Bool
    /// Page title uses the blue **GoDive** gradient + **`.title`** weight.
    let titleUsesBrandForeground: Bool
    /// Flat **`linkedSiteTitleAccent`** title (catalog dive site overview — not brand gradient).
    let titleUsesLinkedSiteAccent: Bool
    let titlePlacement: AppHeaderTitlePlacement
    let trailingContent: TrailingContent
    /// Pass **`GeometryReader.safeAreaInsets.top`** from the tab / page root so the status scrim matches the device inset.
    let statusBarSafeAreaTop: CGFloat
    /// Pale list chrome feather in light mode (certifications, buddies, equipment locker).
    let statusBarUsesListChromeFeather: Bool

    init(
        title: String,
        showsBackButton: Bool = false,
        showsBrandWordmark: Bool = true,
        titleUsesBrandForeground: Bool = false,
        titleUsesLinkedSiteAccent: Bool = false,
        titlePlacement: AppHeaderTitlePlacement = .centered,
        statusBarSafeAreaTop: CGFloat = 0,
        statusBarUsesListChromeFeather: Bool = false,
        @ViewBuilder trailingContent: () -> TrailingContent
    ) {
        self.title = title
        self.showsBackButton = showsBackButton
        self.showsBrandWordmark = showsBrandWordmark
        self.titleUsesBrandForeground = titleUsesBrandForeground
        self.titleUsesLinkedSiteAccent = titleUsesLinkedSiteAccent
        self.titlePlacement = titlePlacement
        self.statusBarSafeAreaTop = statusBarSafeAreaTop
        self.statusBarUsesListChromeFeather = statusBarUsesListChromeFeather
        self.trailingContent = trailingContent()
    }

    var body: some View {
        Group {
            if usesBelowBackRowPlacement {
                belowBackRowHeader
            } else if usesLeadingTitlePlacement {
                leadingTitleHeaderRow
            } else {
                standardHeaderRow
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .appTopChromeVerticalPadding()
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .background(alignment: .top) {
            if statusBarSafeAreaTop > 0.5 {
                AppStatusBarEdgeScrim(
                    safeAreaTop: statusBarSafeAreaTop,
                    usesListChromeFeather: statusBarUsesListChromeFeather
                )
                    .ignoresSafeArea(edges: .top)
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: AppHeaderMetrics.HeightKey.self, value: proxy.size.height)
            }
        }
    }

    /// Back chevron + trailing actions on the first row; full-width title underneath.
    private var belowBackRowHeader: some View {
        VStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                if showsBackButton {
                    SecondaryDestinationBackButton()
                }

                Spacer(minLength: 0)

                HStack(spacing: AppTheme.Spacing.sm) {
                    trailingContent
                }
                .appHeaderChromeIconForeground()
            }

            if !title.isEmpty {
                belowBackRowTitleText
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityLabel(title)
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
            .appHeaderChromeIconForeground()
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
            }
            .frame(maxWidth: .infinity, minHeight: brandHeaderTrailingMinHeight, alignment: .trailing)
            .appHeaderChromeIconForeground()
        }
    }

    private var brandHeaderTrailingMinHeight: CGFloat {
        showsBrandWordmark
            ? max(
                AppHeaderBrandRowMetrics.wordmarkLineHeight,
                BlueSheetTopChromePresentation.homeProfileAvatarDiameter
            )
            : 0
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
                    .frame(minHeight: AppHeaderBrandRowMetrics.wordmarkLineHeight, alignment: .center)
            } else if usesCenteredTitlePlacement, !title.isEmpty {
                headerTitleText
                    .multilineTextAlignment(.center)
            } else {
                Color.clear
            }
        }
        .lineLimit(1)
        .modifier(AppHeaderCenterClusterScalePolicy(isBrandWordmark: showsBrandWordmark))
        .accessibilityLabel(showsBrandWordmark ? appName : title)
        .accessibilityHidden(!showsBrandWordmark && (title.isEmpty || usesLeadingTitlePlacement || usesBelowBackRowPlacement))
    }

    private var headerTitleText: some View {
        pageTitleText
            .multilineTextAlignment(.center)
    }

    private var leadingHeaderTitleText: some View {
        pageTitleText
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var pageTitleText: some View {
        styledHeaderTitle(
            font: pageTitleFont,
            multilineAlignment: usesLeadingTitlePlacement ? .leading : .center,
            lineLimit: usesLeadingTitlePlacement ? 2 : 1
        )
    }

    private var belowBackRowTitleText: some View {
        styledHeaderTitle(
            font: AppTheme.Typography.headerTitle.weight(.bold),
            multilineAlignment: AppHeaderStackedTitleChrome.titleMultilineAlignment,
            lineLimit: nil
        )
    }

    private var pageTitleFont: Font {
        if titleUsesBrandForeground || titleUsesLinkedSiteAccent {
            AppTheme.Typography.headerTitle.weight(.bold)
        } else if usesLeadingTitlePlacement {
            .title3.weight(.bold)
        } else {
            .headline.weight(.semibold)
        }
    }

    @ViewBuilder
    private func styledHeaderTitle(
        font: Font,
        multilineAlignment: TextAlignment,
        lineLimit: Int?
    ) -> some View {
        if let lineLimit {
            styledHeaderTitleText(font: font, multilineAlignment: multilineAlignment)
                .lineLimit(lineLimit)
        } else {
            styledHeaderTitleText(font: font, multilineAlignment: multilineAlignment)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func styledHeaderTitleText(font: Font, multilineAlignment: TextAlignment) -> some View {
        let text = Text(title)
            .font(font)
            .multilineTextAlignment(multilineAlignment)

        if titleUsesLinkedSiteAccent {
            text.foregroundStyle(AppTheme.Colors.linkedSiteTitleAccent)
        } else if titleUsesBrandForeground {
            text.foregroundStyle(AppTheme.Colors.headerTitleForegroundGradient)
        } else {
            text.foregroundStyle(AppTheme.Colors.textPrimary)
        }
    }

    private var usesBelowBackRowPlacement: Bool {
        !showsBrandWordmark && titlePlacement == .belowBackRow
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
        titleUsesBrandForeground: Bool = false,
        titleUsesLinkedSiteAccent: Bool = false,
        titlePlacement: AppHeaderTitlePlacement = .centered,
        statusBarSafeAreaTop: CGFloat = 0,
        statusBarUsesListChromeFeather: Bool = false
    ) {
        self.init(
            title: title,
            showsBackButton: showsBackButton,
            showsBrandWordmark: showsBrandWordmark,
            titleUsesBrandForeground: titleUsesBrandForeground,
            titleUsesLinkedSiteAccent: titleUsesLinkedSiteAccent,
            titlePlacement: titlePlacement,
            statusBarSafeAreaTop: statusBarSafeAreaTop,
            statusBarUsesListChromeFeather: statusBarUsesListChromeFeather
        ) {
            EmptyView()
        }
    }
}

/// Brand wordmark stays at full **`.largeTitle`**; page titles may shrink in tight chrome.
private struct AppHeaderCenterClusterScalePolicy: ViewModifier {
    let isBrandWordmark: Bool

    func body(content: Content) -> some View {
        if isBrandWordmark {
            content.fixedSize(horizontal: true, vertical: false)
        } else {
            content
                .minimumScaleFactor(0.82)
                .allowsTightening(true)
        }
    }
}

/// Shared vertical metrics when **`AppHeader`** shows the **GoDive** wordmark + Home profile avatar.
enum AppHeaderBrandRowMetrics {
    nonisolated static var wordmarkLineHeight: CGFloat {
        #if canImport(UIKit)
        ceil(UIFont.preferredFont(forTextStyle: .largeTitle).lineHeight)
        #else
        41
        #endif
    }
}

#Preview {
    AppHeader(title: "Home", statusBarSafeAreaTop: 54)
        .background(AppTheme.Colors.screenBackgroundGradient)
}
