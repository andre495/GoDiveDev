import SwiftUI

/// Logged-out welcome — multi-select water activities + optional sign-in link.
struct LoggedOutOnboardingWelcomeView: View {
    @Binding var selection: UserOnboardingActivitySelection
    let onContinue: () -> Void
    let onSignIn: () -> Void

    @State private var headerVisible = false
    @State private var cardsVisible = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer(minLength: AppTheme.Spacing.md)

            VStack(spacing: AppTheme.Spacing.md) {
                GoDiveLogoPinPresentation.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .scaleEffect(headerVisible ? 1 : 0.85)
                    .opacity(headerVisible ? 1 : 0)
                    .accessibilityHidden(true)

                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("Welcome to")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)

                    GoDiveBrandWordmarkText()

                    Text(AppLoggedOutOnboardingPresentation.welcomeSubtitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(AppLoggedOutOnboardingPresentation.welcomeTitle). \(AppLoggedOutOnboardingPresentation.welcomeSubtitle)"
            )
            .accessibilityIdentifier(AppLoggedOutOnboardingPresentation.welcomeAccessibilityIdentifier)

            UserOnboardingActivitySelectionCards(selection: $selection)
                .opacity(cardsVisible ? 1 : 0)

            Spacer(minLength: AppTheme.Spacing.md)

            Button(AppLoggedOutOnboardingPresentation.welcomeContinueTitle) {
                onContinue()
            }
            .appOnboardingPrimaryGlassButtonStyle()
            .disabled(!selection.hasAnySelection)
            .accessibilityIdentifier("LoggedOutOnboarding.Welcome.Continue")

            Button(AppLoggedOutOnboardingPresentation.existingAccountSignInTitle) {
                onSignIn()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .accessibilityIdentifier("LoggedOutOnboarding.Welcome.SignIn")
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                headerVisible = true
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.08)) {
                cardsVisible = true
            }
        }
    }
}
