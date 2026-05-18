import SwiftUI

struct AppHeaderlessPage<Content: View>: View {
    let content: Content
    var leadingEdgePopOnWillDismiss: (() -> Void)?

    init(
        leadingEdgePopOnWillDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
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
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationInteractivePopGestureForHiddenNavBar()
            .goDiveLeadingEdgeSwipePopOverlay(onWillDismiss: leadingEdgePopOnWillDismiss)
    }
}

#Preview {
    AppHeaderlessPage {
        Spacer()
    }
}
