import SwiftUI

struct FieldGuideView: View {
    var body: some View {
        NavigationStack {
            AppHeaderlessPage {
                ZStack {
                    if !GoDiveUITestConfiguration.isActive {
                        WaterBubbleBackground()
                    }

                    VStack {
                        Spacer(minLength: AppTheme.Spacing.lg)

                        AppComingSoonPlaceholder(
                            systemImage: "leaf",
                            message: "Species guides and marine life notes are on the way."
                        )

                        Spacer()
                    }
                }
            }
        }
        .navigationInteractivePopGestureForHiddenNavBar()
    }
}

#Preview {
    FieldGuideView()
}
