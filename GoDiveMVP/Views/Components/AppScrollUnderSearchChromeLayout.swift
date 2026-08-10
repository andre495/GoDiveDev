import SwiftUI

/// Inset math for modal sheets with sticky search chrome (no status-bar safe area — toolbar owns that).
enum AppScrollUnderSearchChromePresentation: Sendable {
    /// Fallback before measured chrome publishes **`AppHeaderMetrics.HeightKey`**.
    nonisolated static let chromeClearanceFallback: CGFloat =
        CollapsibleInlineTitleHeaderPresentation.chromeBandHeight

    nonisolated static let listScrollFadeFeatherHeight: CGFloat =
        CollapsibleInlineTitleHeaderPresentation.listScrollFadeFeatherHeight

    /// List / empty-state top clearance — **chrome only** (sheet content already sits under the nav bar).
    nonisolated static func listTopInset(chromeClearance: CGFloat) -> CGFloat {
        chromeClearance
    }

    nonisolated static func scrimBandHeight(chromeClearance: CGFloat) -> CGFloat {
        listTopInset(chromeClearance: chromeClearance) + listScrollFadeFeatherHeight
    }
}

/// Modal sheet body: sticky search chrome over scrolling content on a shared panel background.
///
/// Use inside a **`NavigationStack`** sheet where the toolbar already owns the top safe area.
/// Do **not** add window status-bar inset or **`.ignoresSafeArea(edges: .top)`**.
struct AppScrollUnderSearchChromeLayout<Chrome: View, Content: View>: View {
    @ViewBuilder private let chrome: () -> Chrome
    @ViewBuilder private let content: (_ chromeClearance: CGFloat) -> Content

    @State private var chromeClearance: CGFloat =
        AppScrollUnderSearchChromePresentation.chromeClearanceFallback

    init(
        @ViewBuilder chrome: @escaping () -> Chrome,
        @ViewBuilder content: @escaping (_ chromeClearance: CGFloat) -> Content
    ) {
        self.chrome = chrome
        self.content = content
    }

    var body: some View {
        let topInset = AppScrollUnderSearchChromePresentation.listTopInset(
            chromeClearance: chromeClearance
        )

        ZStack(alignment: .top) {
            content(topInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LogbookTopChromeScrim(
                topObstructionHeight: topInset,
                featherHeight: AppScrollUnderSearchChromePresentation.listScrollFadeFeatherHeight
            )
            .allowsHitTesting(false)
            .zIndex(0.5)

            chrome()
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: AppHeaderMetrics.HeightKey.self,
                            value: proxy.size.height
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
            if height > 0 {
                chromeClearance = height
            }
        }
    }
}
