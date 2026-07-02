import SwiftUI

struct AppHeaderlessPage<Content: View>: View {
    let content: Content
    var hidesNavigationBar: Bool
    var leadingEdgePopOnWillDismiss: (() -> Void)?

    init(
        hidesNavigationBar: Bool = true,
        leadingEdgePopOnWillDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.hidesNavigationBar = hidesNavigationBar
        self.leadingEdgePopOnWillDismiss = leadingEdgePopOnWillDismiss
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                AppTheme.Colors.screenBackgroundGradient
                    .ignoresSafeArea()
            }
            .modifier(AppHeaderlessNavigationBarVisibilityModifier(hidesNavigationBar: hidesNavigationBar))
            .navigationInteractivePopGestureForHiddenNavBar()
            .goDiveLeadingEdgeSwipePopOverlay(onWillDismiss: leadingEdgePopOnWillDismiss)
    }
}

private struct AppHeaderlessNavigationBarVisibilityModifier: ViewModifier {
    let hidesNavigationBar: Bool

    func body(content: Content) -> some View {
        if hidesNavigationBar {
            content
                .toolbar(.hidden, for: .navigationBar)
                .toolbarBackground(.hidden, for: .navigationBar)
        } else {
            content
        }
    }
}

#Preview {
    AppHeaderlessPage {
        Spacer()
    }
}
