import SwiftUI

/// Shown once after the first Sign in with Apple — before Contacts + Photos system prompts.
struct NewAccountWelcomeView: View {
    let displayName: String?
    let onContinue: () -> Void

    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                VStack(spacing: AppTheme.Spacing.lg) {
                    GoDiveLogoPinPresentation.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .accessibilityHidden(true)

                    VStack(spacing: AppTheme.Spacing.sm) {
                        Text(AppNewAccountWelcomePresentation.welcomeTitle(displayName: displayName))
                            .font(.title.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .accessibilityElement(children: .combine)

                    permissionsCard
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, headerClearance)
                .padding(.bottom, AppTheme.Spacing.md)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)

                AppHeader(
                    title: "",
                    showsBackButton: false,
                    statusBarSafeAreaTop: proxy.safeAreaInsets.top
                )
                .zIndex(1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            AppTheme.Colors.screenBackgroundGradient
                .ignoresSafeArea()
        }
        .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
            if height > 0 { headerClearance = height }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(AppNewAccountWelcomePresentation.continueButtonTitle) {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.accentDeep)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.sm)
            .padding(.bottom, AppTheme.Spacing.md)
            .accessibilityIdentifier("NewAccountWelcome.Continue")
        }
        .accessibilityIdentifier("NewAccountWelcome.Root")
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text(AppNewAccountWelcomePresentation.permissionsLeadIn)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            permissionRow(
                systemImage: "person.crop.circle",
                title: AppNewAccountWelcomePresentation.contactsPermissionTitle,
                body: AppNewAccountWelcomePresentation.contactsPermissionBody
            )

            permissionRow(
                systemImage: "photo.on.rectangle.angled",
                title: AppNewAccountWelcomePresentation.photosPermissionTitle,
                body: AppNewAccountWelcomePresentation.photosPermissionBody
            )

            Spacer(minLength: 0)

            Text(AppNewAccountWelcomePresentation.permissionsFooter)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.Colors.accentDeep.opacity(0.12), lineWidth: 1)
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
}

#Preview {
    NewAccountWelcomeView(displayName: "Casey") {}
}
