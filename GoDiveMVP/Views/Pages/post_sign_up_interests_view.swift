import SwiftUI

/// After Sign in with Apple for a brand-new account that skipped welcome interests.
struct PostSignUpInterestsView: View {
    let onContinue: (UserOnboardingActivitySelection) -> Void

    @State private var selection = UserOnboardingActivitySelection.welcomeDefault

    var body: some View {
        LoggedOutMarketingChrome {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer(minLength: AppTheme.Spacing.md)

                VStack(spacing: AppTheme.Spacing.md) {
                    interestsIconBadge

                    VStack(spacing: AppTheme.Spacing.sm) {
                        Text(PostSignUpInterestsPresentation.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(PostSignUpInterestsPresentation.subtitle)
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    UserOnboardingActivitySelectionCards(selection: $selection)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }

                Spacer(minLength: AppTheme.Spacing.md)

                Button(PostSignUpInterestsPresentation.continueTitle) {
                    onContinue(selection)
                }
                .appOnboardingPrimaryGlassButtonStyle()
                .disabled(!selection.hasAnySelection)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.lg)
                .accessibilityIdentifier(PostSignUpInterestsPresentation.continueAccessibilityIdentifier)
            }
        }
        .accessibilityIdentifier(PostSignUpInterestsPresentation.rootAccessibilityIdentifier)
    }

    private var interestsIconBadge: some View {
        Image(systemName: "figure.water.fitness")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 72, height: 72)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.accent,
                                AppTheme.Colors.accent.opacity(0.78),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: AppTheme.Colors.accent.opacity(0.28), radius: 8, y: 4)
            .accessibilityHidden(true)
    }
}
