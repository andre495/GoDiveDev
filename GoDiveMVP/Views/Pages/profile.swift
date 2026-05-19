import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AppHeaderlessPage {
            ZStack {
                if !GoDiveUITestConfiguration.isActive {
                    WaterBubbleBackground()
                }

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

                    profileHeader
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, AppTheme.Spacing.sm)

                    equipmentLockerLink
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, AppTheme.Spacing.lg)

                    Spacer()

                    signOutButton
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.bottom, AppTheme.Spacing.lg)
                }
            }
        }
        .hidesBottomTabBarWhenPushed()
    }

    private var profileHeader: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text(accountSession.currentProfile?.displayName ?? UserProfileStore.defaultDisplayName)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("Profile.DisplayName")

            Text("Rescue Diver")
                .font(.title3.weight(.medium))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("Profile.CertificationSubtitle")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var equipmentLockerLink: some View {
        NavigationLink {
            EquipmentLockerView()
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "archivebox.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Colors.accent)
                    .accessibilityHidden(true)

                Text("Equipment Locker")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .padding(AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Profile.EquipmentLockerLink")
    }

    private var signOutButton: some View {
        Button("Sign out", role: .destructive) {
            accountSession.signOut()
            dismiss()
        }
        .font(.body.weight(.semibold))
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("Profile.SignOut")
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environment(AccountSession.shared)
    .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
