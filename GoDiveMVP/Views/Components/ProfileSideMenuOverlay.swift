import SwiftUI

/// Trailing overlay panel for **Profile** (~⅔ screen width). Title-only destinations.
struct ProfileSideMenuOverlay: View {
    let isPresented: Bool
    let onDismiss: () -> Void
    let onEditProfile: () -> Void
    let onSettings: () -> Void
    let onCertifications: () -> Void
    let onEquipment: () -> Void
    let onBuddies: () -> Void
    let onTrips: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let panelWidth = geometry.size.width * ProfilePresentation.sideMenuWidthFraction

            ZStack(alignment: .trailing) {
                if isPresented {
                    Color.black.opacity(0.42)
                        .ignoresSafeArea()
                        .onTapGesture(perform: onDismiss)
                        .accessibilityLabel(ProfilePresentation.menuCloseAccessibilityLabel)
                        .accessibilityAddTraits(.isButton)
                        .transition(.opacity)
                }

                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    panel
                        .frame(width: panelWidth)
                        .frame(maxHeight: .infinity)
                        .background {
                            AppOverviewSheetPanelBackground()
                                .ignoresSafeArea()
                        }
                        .offset(x: isPresented ? 0 : panelWidth)
                }
            }
            .animation(.snappy(duration: 0.28), value: isPresented)
            .allowsHitTesting(isPresented)
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .appToolbarIconButtonLabel()
                }
                .appStandaloneIconButtonStyle()
                .appHeaderChromeIconForeground()
                .accessibilityLabel(ProfilePresentation.menuCloseAccessibilityLabel)
                .accessibilityIdentifier("Profile.SideMenu.Close")
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.top, AppTheme.Spacing.sm)
            .padding(.bottom, AppTheme.Spacing.md)

            VStack(alignment: .leading, spacing: 0) {
                menuRow(
                    title: ProfilePresentation.menuTripsTitle,
                    accessibilityIdentifier: "Profile.TripsLink",
                    action: onTrips
                )
                menuRow(
                    title: ProfilePresentation.menuCertificationsTitle,
                    accessibilityIdentifier: "Profile.CertificationsLink",
                    action: onCertifications
                )
                menuRow(
                    title: ProfilePresentation.menuEquipmentTitle,
                    accessibilityIdentifier: "Profile.EquipmentLockerLink",
                    action: onEquipment
                )
                menuRow(
                    title: ProfilePresentation.menuBuddiesTitle,
                    accessibilityIdentifier: "Profile.DiveBuddiesLink",
                    action: onBuddies
                )
                menuRow(
                    title: ProfilePresentation.menuEditProfileTitle,
                    accessibilityIdentifier: "Profile.EditButton",
                    action: onEditProfile
                )
                menuRow(
                    title: ProfilePresentation.menuSettingsTitle,
                    accessibilityIdentifier: "Profile.SettingsButton",
                    action: onSettings
                )
            }
            .padding(.horizontal, AppTheme.Spacing.lg)

            Spacer(minLength: 0)

            Button(action: onSignOut) {
                Text(ProfilePresentation.menuSignOutTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.lg)
            .accessibilityIdentifier("Profile.SignOut")
        }
        .accessibilityIdentifier("Profile.SideMenu")
    }

    private func menuRow(
        title: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, AppTheme.Spacing.md)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
