import SwiftData
import SwiftUI

struct SignInView: View {
    @Environment(AccountSession.self) private var accountSession

    var body: some View {
        LoggedOutMarketingChrome {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer(minLength: AppTheme.Spacing.lg)

                VStack(spacing: AppTheme.Spacing.md) {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        GoDiveLogoPinPresentation.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 128, height: 128)
                            .accessibilityHidden(true)
                            .accessibilityIdentifier("SignIn.Logo")

                        Text("GoDive")
                            .font(AppTheme.Typography.headerBrandTitle.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }

                    Text("Log every dive. Explore marine life. Connect with buddies.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "GoDive. Log every dive. Explore marine life. Connect with buddies."
                )

                SignInWithAppleSection()
                    .padding(.horizontal, AppTheme.Spacing.lg)

                Spacer()
            }
        }
        .accessibilityIdentifier("SignIn.Root")
    }
}

#Preview {
    SignInView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
