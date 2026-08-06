import SwiftUI

struct AppHeaderlessPage<Content: View>: View {
    let content: Content
    var hidesNavigationBar: Bool
    /// When **`false`**, no fill — use for pages that sit over a tab-level **`WaterBubbleBackground`**.
    var showsScreenBackgroundGradient: Bool
    var leadingEdgePopOnWillDismiss: (() -> Void)?

    init(
        hidesNavigationBar: Bool = true,
        showsScreenBackgroundGradient: Bool = true,
        leadingEdgePopOnWillDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.hidesNavigationBar = hidesNavigationBar
        self.showsScreenBackgroundGradient = showsScreenBackgroundGradient
        self.leadingEdgePopOnWillDismiss = leadingEdgePopOnWillDismiss
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if showsScreenBackgroundGradient {
                    AppTheme.Colors.screenBackgroundGradient
                        .ignoresSafeArea()
                }
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
