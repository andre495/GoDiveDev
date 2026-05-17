import SwiftUI

struct AppPage<Content: View, TrailingContent: View>: View {
    let title: String
    let showsBackButton: Bool
    let content: Content
    let trailingContent: TrailingContent

    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback

    init(
        title: String,
        showsBackButton: Bool = false,
        @ViewBuilder trailingContent: () -> TrailingContent,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsBackButton = showsBackButton
        self.trailingContent = trailingContent()
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, headerClearance)

                AppHeader(
                    title: title,
                    showsBackButton: showsBackButton,
                    statusBarSafeAreaTop: proxy.safeAreaInsets.top
                ) {
                    trailingContent
                }
                .zIndex(1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            AppTheme.Colors.screenBackgroundGradient
                .ignoresSafeArea()
        }
        .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
            if height > 0 { headerClearance = height }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationInteractivePopGestureForHiddenNavBar()
        .goDiveLeadingEdgeSwipePopOverlay(enabled: showsBackButton)
    }
}

extension AppPage where TrailingContent == EmptyView {
    init(
        title: String,
        showsBackButton: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, showsBackButton: showsBackButton, trailingContent: {
            EmptyView()
        }, content: content)
    }
}

#Preview {
    AppPage(title: "Home") {
        Spacer()
    }
}
