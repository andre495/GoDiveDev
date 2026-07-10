import SwiftUI

/// After profile setup — optional MacDive / UDDF bulk import before the bubble celebration.
struct PostSignUpImportOfferView: View {
    let onImport: () -> Void
    let onSkip: () -> Void

    var body: some View {
        LoggedOutMarketingChrome {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer(minLength: AppTheme.Spacing.md)

                VStack(spacing: AppTheme.Spacing.md) {
                    importIconBadge

                    VStack(spacing: AppTheme.Spacing.sm) {
                        Text(PostSignUpImportOfferPresentation.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(PostSignUpImportOfferPresentation.subtitle)
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    macDiveHintCard
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }

                Spacer(minLength: AppTheme.Spacing.md)

                bottomChrome
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.bottom, AppTheme.Spacing.lg)
            }
        }
        .accessibilityIdentifier(PostSignUpImportOfferPresentation.rootAccessibilityIdentifier)
    }

    private var importIconBadge: some View {
        Image(systemName: "doc.on.doc.fill")
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

    private var macDiveHintCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(PostSignUpImportOfferPresentation.macDiveHintTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text(PostSignUpImportOfferPresentation.macDiveHintBody)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.16), lineWidth: 1)
        }
    }

    private var bottomChrome: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Button(PostSignUpImportOfferPresentation.importButtonTitle, action: onImport)
                .appOnboardingPrimaryGlassButtonStyle()
                .accessibilityIdentifier(PostSignUpImportOfferPresentation.importButtonAccessibilityIdentifier)

            Button(PostSignUpImportOfferPresentation.skipButtonTitle, action: onSkip)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .accessibilityIdentifier(PostSignUpImportOfferPresentation.skipButtonAccessibilityIdentifier)
        }
    }
}

#Preview {
    PostSignUpImportOfferView(onImport: {}, onSkip: {})
}
