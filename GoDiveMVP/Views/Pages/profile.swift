import SwiftUI

struct ProfileView: View {
    var body: some View {
        AppHeaderlessPage {
            ZStack {
                WaterBubbleBackground()

                VStack(spacing: 0) {
                    HStack(spacing: AppTheme.Spacing.md) {
                        SecondaryDestinationBackButton()

                        Spacer()

                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.Colors.iconPrimary)
                        .accessibilityLabel("Settings")
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, AppTheme.Spacing.md)

                    Spacer()
                }
            }
        }
        .hidesBottomTabBarWhenPushed()
    }
}

#Preview {
    ProfileView()
}
