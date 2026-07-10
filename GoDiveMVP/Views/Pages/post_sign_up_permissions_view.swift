import SwiftUI

/// After profile setup — explains Contacts + Photos access, then runs system prompts before import offer.
struct PostSignUpPermissionsView: View {
    let onContinue: () -> Void

    @State private var isRequestingPermissions = false

    var body: some View {
        LoggedOutMarketingChrome {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer(minLength: AppTheme.Spacing.md)

                VStack(spacing: AppTheme.Spacing.md) {
                    permissionsIconBadge

                    VStack(spacing: AppTheme.Spacing.sm) {
                        Text(PostSignUpPermissionsPresentation.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(PostSignUpPermissionsPresentation.subtitle)
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    permissionsCard
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }

                Spacer(minLength: AppTheme.Spacing.md)

                bottomChrome
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.bottom, AppTheme.Spacing.lg)
            }
        }
        .accessibilityIdentifier(PostSignUpPermissionsPresentation.rootAccessibilityIdentifier)
    }

    private var permissionsIconBadge: some View {
        Image(systemName: "person.crop.circle.badge.checkmark")
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

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            permissionRow(
                systemImage: "person.crop.circle",
                title: PostSignUpPermissionsPresentation.contactsTitle,
                body: PostSignUpPermissionsPresentation.contactsBody
            )

            permissionRow(
                systemImage: "photo.on.rectangle.angled",
                title: PostSignUpPermissionsPresentation.photosTitle,
                body: PostSignUpPermissionsPresentation.photosBody
            )

            Text(PostSignUpPermissionsPresentation.footer)
                .font(.footnote)
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

    private func permissionRow(systemImage: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(AppTheme.Colors.accentDeep)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var bottomChrome: some View {
        Button(PostSignUpPermissionsPresentation.continueButtonTitle) {
            guard !isRequestingPermissions else { return }
            isRequestingPermissions = true
            Task {
                await AppOnboardingPermissions.requestForNewAccount()
                isRequestingPermissions = false
                onContinue()
            }
        }
        .appOnboardingPrimaryGlassButtonStyle()
        .disabled(isRequestingPermissions)
        .accessibilityIdentifier(PostSignUpPermissionsPresentation.continueButtonAccessibilityIdentifier)
    }
}

#Preview {
    PostSignUpPermissionsView(onContinue: {})
}
