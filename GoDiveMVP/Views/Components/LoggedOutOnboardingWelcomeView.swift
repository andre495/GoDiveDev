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

            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(Array(UserOnboardingActivityKind.allCases.enumerated()), id: \.element.id) { index, kind in
                    activityCard(for: kind)
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 18)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.82).delay(Double(index) * 0.08),
                            value: cardsVisible
                        )
                }
            }

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

    private func activityCard(for kind: UserOnboardingActivityKind) -> some View {
        let isSelected = selection.contains(kind)

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                selection.toggle(kind)
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? AppTheme.Colors.accentDeep.opacity(0.22)
                                : AppTheme.Colors.surfaceElevated.opacity(0.65)
                        )
                        .frame(width: 48, height: 48)

                    activityIcon(for: kind, isSelected: isSelected)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(kind.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppTheme.Colors.accentDeep : AppTheme.Colors.tabUnselected.opacity(0.5))
                    .accessibilityHidden(true)
            }
            .padding(AppTheme.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated.opacity(isSelected ? 0.95 : 0.72))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? AppTheme.Colors.accentDeep.opacity(0.55) : AppTheme.Colors.tabUnselected.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(kind.accessibilityIdentifier)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func activityIcon(for kind: UserOnboardingActivityKind, isSelected: Bool) -> some View {
        let tint = isSelected ? AppTheme.Colors.accentDeep : AppTheme.Colors.tabUnselected

        if let assetName = kind.assetImageName {
            let size = DiveActivityTabIcon.scaledAssetSize(
                assetPixelSize: DiveActivityTabIcon.scubaTankTabAssetPixelSize,
                targetHeight: 22
            )
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .foregroundStyle(tint)
                .scaleEffect(isSelected ? 1.14 : 1)
                .animation(.spring(response: 0.32, dampingFraction: 0.55), value: isSelected)
        } else if let systemImage = kind.systemImage {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: isSelected)
        }
    }
}
