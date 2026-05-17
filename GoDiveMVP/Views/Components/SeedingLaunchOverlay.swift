import SwiftUI

struct SeedingLaunchOverlay: View {
    var body: some View {
        ZStack {
            AppTheme.Colors.screenBackgroundGradient
                .ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.md) {
                Text("GoDive")
                    .font(.title.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.Colors.headerGradientStart, AppTheme.Colors.headerGradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(AppTheme.Colors.tabSelected)
                    .scaleEffect(1.2)

                Text("Seeding dive data...")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
            .padding(AppTheme.Spacing.lg)
        }
    }
}

#Preview {
    SeedingLaunchOverlay()
}
