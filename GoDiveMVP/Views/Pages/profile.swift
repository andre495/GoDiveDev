import SwiftData
import SwiftUI

struct ProfileView: View {
    private enum Layout {
        /// Dark veil between **`WaterBubbleBackground`** and profile content.
        static let bubbleScrimOpacity: CGFloat = 0.48
        static let tileCornerRadius: CGFloat = 16
        static let headerSpacing: CGFloat = 20
    }

    @Environment(AccountSession.self) private var accountSession
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Certification.dateAttained, order: .reverse)])
    private var allCertifications: [Certification]

    @Query private var allDiveActivities: [DiveActivity]

    private var ownedCertifications: [Certification] {
        guard let ownerID = accountSession.currentProfile?.id else { return [] }
        return allCertifications.filter { $0.ownerProfileID == ownerID }
    }

    private var profilePrimaryCertification: CertificationPresentation.ProfilePrimaryCertificationDisplay {
        CertificationPresentation.profilePrimaryCertification(from: ownedCertifications)
    }

    private var ownedDiveActivityCount: Int {
        guard let ownerID = accountSession.currentProfile?.id else { return 0 }
        return allDiveActivities.filter { $0.ownerProfileID == ownerID }.count
    }

    private var diveCountLabel: String {
        ProfilePresentation.diveActivityCountLabel(ownedDiveActivityCount)
    }

    var body: some View {
        AppHeaderlessPage {
            ZStack {
                if !GoDiveUITestConfiguration.isActive {
                    WaterBubbleBackground()
                    Color.black
                        .opacity(Layout.bubbleScrimOpacity)
                        .ignoresSafeArea()
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
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
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

                    Spacer(minLength: AppTheme.Spacing.lg)

                    profileDestinationTiles
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.bottom, AppTheme.Spacing.lg)

                    signOutButton
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.bottom, AppTheme.Spacing.lg)
                }
            }
        }
        .hidesBottomTabBarWhenPushed()
    }

    private var profileHeader: some View {
        VStack(spacing: Layout.headerSpacing) {
            if let profile = accountSession.currentProfile {
                ProfileAvatarEditor(profile: profile)
            }

            VStack(spacing: AppTheme.Spacing.sm) {
                Text(accountSession.currentProfile?.displayName ?? UserProfileStore.defaultDisplayName)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("Profile.DisplayName")

                Text(profilePrimaryCertification.title)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("Profile.CertificationSubtitle")

                if let certNumber = profilePrimaryCertification.certNumber {
                    Text(certNumber)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("Profile.CertificationNumber")
                }

                Text(diveCountLabel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("Profile.DiveCount")
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity)
    }

    private var profileDestinationTiles: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            profileDestinationTile(
                title: "Certifications",
                systemImage: "checkmark.seal.fill",
                accessibilityIdentifier: "Profile.CertificationsLink"
            ) {
                CertificationsListView()
            }

            profileDestinationTile(
                title: "Equipment Locker",
                systemImage: "archivebox.fill",
                accessibilityIdentifier: "Profile.EquipmentLockerLink"
            ) {
                EquipmentLockerView()
            }
        }
    }

    private func profileDestinationTile<Destination: View>(
        title: String,
        systemImage: String,
        accessibilityIdentifier: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            VStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 34))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(AppTheme.Spacing.md)
            .aspectRatio(1, contentMode: .fit)
            .background {
                RoundedRectangle(cornerRadius: Layout.tileCornerRadius, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Layout.tileCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.Colors.accentDeep.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier)
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
