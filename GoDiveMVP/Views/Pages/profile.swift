import SwiftData
import SwiftUI

struct ProfileView: View {
    private enum Layout {
        static let headerSpacing: CGFloat = 16
        static let profileAvatarDiameter: CGFloat = 168
    }

    @Environment(\.openTripPlanner) private var openTripPlanner
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Certification.dateAttained, order: .reverse)])
    private var allCertifications: [Certification]

    @Query(
        sort: [
            SortDescriptor(\EquipmentItem.manufacturer, order: .forward),
            SortDescriptor(\EquipmentItem.model, order: .forward),
        ]
    )
    private var allEquipment: [EquipmentItem]

    @Query private var allDiveActivities: [DiveActivity]

    @Query(
        sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
    )
    private var allDiveBuddies: [DiveBuddy]

    @Query(
        sort: [
            SortDescriptor(\DiveTrip.startDate, order: .reverse),
            SortDescriptor(\DiveTrip.createdAt, order: .reverse),
        ]
    )
    private var allTrips: [DiveTrip]

    @Query(sort: [SortDescriptor(\DiveMediaBuddyTag.id, order: .forward)])
    private var buddyMediaTags: [DiveMediaBuddyTag]

    @State private var showsProfileEditSheet = false
    @State private var showsSignOutConfirmation = false
    @State private var selfBuddyID: UUID?

    private var ownedCertifications: [Certification] {
        guard let ownerID = accountSession.currentProfile?.id else { return [] }
        return allCertifications.filter { $0.ownerProfileID == ownerID }
    }

    private var ownedEquipment: [EquipmentItem] {
        guard let ownerID = accountSession.currentProfile?.id else { return [] }
        return allEquipment.filter { $0.ownerProfileID == ownerID }
    }

    private var certificationCountLabel: String {
        ProfilePresentation.certificationCountLabel(ownedCertifications.count)
    }

    private var equipmentItemCountLabel: String {
        ProfilePresentation.equipmentItemCountLabel(ownedEquipment.count)
    }

    private var ownedDiveBuddies: [DiveBuddy] {
        guard let ownerID = accountSession.currentProfile?.id else { return [] }
        let buddies = allDiveBuddies.filter { $0.ownerProfileID == ownerID }
        return DiveBuddySelfRepresentation.rosterBuddiesExcludingSelf(
            buddies,
            owner: accountSession.currentProfile
        )
    }

    private var diveBuddyCountLabel: String {
        ProfilePresentation.diveBuddyRosterCountLabel(ownedDiveBuddies.count)
    }

    private var ownedTrips: [DiveTrip] {
        guard let ownerID = accountSession.currentProfile?.id else { return [] }
        return allTrips.filter { $0.ownerProfileID == ownerID }
    }

    private var tripCountLabel: String {
        ProfilePresentation.tripCountLabel(ownedTrips.count)
    }

    private var profileFeaturedCertification: CertificationPresentation.ProfileFeaturedCertificationDisplay? {
        CertificationPresentation.profileFeaturedCertification(from: ownedCertifications)
    }

    private var featuredCertificationCard: Certification? {
        CertificationPresentation.profileFeaturedCertificationCard(from: ownedCertifications)
    }

    private var ownedDiveActivityCount: Int {
        guard let ownerID = accountSession.currentProfile?.id else { return 0 }
        return allDiveActivities.filter { $0.ownerProfileID == ownerID }.count
    }

    private var diveCountLabel: String {
        ProfilePresentation.diveActivityCountLabel(ownedDiveActivityCount)
    }

    private var ownerDiveActivityIDs: Set<UUID> {
        guard let ownerID = accountSession.currentProfile?.id else { return [] }
        return Set(
            allDiveActivities
                .filter { $0.ownerProfileID == ownerID }
                .map(\.id)
        )
    }

    private var taggedMediaCount: Int {
        guard let selfBuddyID else { return 0 }
        return ProfileTaggedMediaPresentation.uniqueTaggedMediaCount(
            tags: buddyMediaTags,
            buddyID: selfBuddyID,
            ownerDiveActivityIDs: ownerDiveActivityIDs
        )
    }

    private var taggedMediaCountLabel: String {
        ProfileTaggedMediaPresentation.mediaCountLabel(taggedMediaCount)
    }

    var body: some View {
        AppHeaderlessPage {
            ZStack {
                ProfileBubbleBackgroundLayer()

                VStack(spacing: 0) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        SecondaryDestinationBackButton()

                        Spacer()

                        GlassEffectContainer {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                if accountSession.currentProfile != nil {
                                    AppEditToolbarButton(
                                        action: { showsProfileEditSheet = true },
                                        accessibilityIdentifier: "Profile.EditButton",
                                        accessibilityLabel: "Edit profile"
                                    )
                                }

                                NavigationLink {
                                    SettingsView()
                                } label: {
                                    Image(systemName: "gearshape")
                                        .appToolbarIconButtonLabel()
                                }
                                .appStandaloneIconButtonStyle()
                                .accessibilityLabel("Settings")
                                .accessibilityIdentifier("Profile.SettingsButton")
                            }
                            .appGlassChromeControlRowHeight()
                            .appHeaderChromeIconForeground()
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.top, AppTheme.Spacing.sm)
                    .padding(.bottom, AppTheme.Spacing.sm)

                    profileHeader
                        .padding(.horizontal, AppTheme.Spacing.lg)

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
        .sheet(isPresented: $showsProfileEditSheet) {
            if let profile = accountSession.currentProfile {
                ProfileEditSheet(profile: profile)
            }
        }
        .alert(
            ProfilePresentation.signOutConfirmationTitle,
            isPresented: $showsSignOutConfirmation
        ) {
            Button(ProfilePresentation.signOutCancelButtonTitle, role: .cancel) {}
            Button(ProfilePresentation.signOutConfirmButtonTitle, role: .destructive) {
                accountSession.signOut()
                dismiss()
            }
        } message: {
            Text(ProfilePresentation.signOutConfirmationMessage)
        }
        .task(id: accountSession.currentProfile?.id) {
            selfBuddyID = DiveBuddySelfRepresentation.resolveSelfBuddyID(
                owner: accountSession.currentProfile,
                modelContext: modelContext
            )
        }
        .hidesBottomTabBarWhenPushed()
    }

    private var profileHeader: some View {
        VStack(spacing: Layout.headerSpacing) {
            if let profile = accountSession.currentProfile {
                ProfileAvatarEditor(diameter: Layout.profileAvatarDiameter, profile: profile)
            }

            VStack(spacing: AppTheme.Spacing.sm) {
                Text(accountSession.currentProfile?.displayName ?? UserProfileStore.defaultDisplayName)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)

                if let dan = accountSession.currentProfile?.danInsuranceNumber, !dan.isEmpty {
                    Text(ProfilePresentation.danInsuranceLabel(dan))
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("Profile.DanInsuranceNumber")
                }

                profileFeaturedCertificationSummary

                Text(diveCountLabel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("Profile.DiveCount")
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var profileFeaturedCertificationSummary: some View {
        if let display = profileFeaturedCertification, let featured = featuredCertificationCard {
            NavigationLink {
                ViewCertificationDetails(certification: featured)
            } label: {
                profileCertificationSummaryLabels(display: display)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View certification, \(display.title)")
            .accessibilityIdentifier("Profile.FeaturedCertificationLink")
        }
    }

    private func profileCertificationSummaryLabels(
        display: CertificationPresentation.ProfileFeaturedCertificationDisplay
    ) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text(display.title)
                .font(.title3.weight(.medium))
                .foregroundStyle(AppTheme.Colors.tabSelected)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("Profile.CertificationSubtitle")

            if let certNumber = display.certNumber {
                Text(certNumber)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("Profile.CertificationNumber")
            }
        }
    }

    private var profileDestinationTiles: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            profileDestinationTile(
                title: "Certifications",
                subtitle: certificationCountLabel,
                systemImage: "checkmark.seal.fill",
                accessibilityIdentifier: "Profile.CertificationsLink"
            ) {
                CertificationsListView()
            }

            profileDestinationTile(
                title: "Equipment Locker",
                subtitle: equipmentItemCountLabel,
                systemImage: "archivebox.fill",
                accessibilityIdentifier: "Profile.EquipmentLockerLink"
            ) {
                EquipmentLockerView()
            }

            profileDestinationTile(
                title: "Dive Buddies",
                subtitle: diveBuddyCountLabel,
                systemImage: "person.2.fill",
                accessibilityIdentifier: "Profile.DiveBuddiesLink"
            ) {
                DiveBuddiesListView()
            }

            profileDestinationTile(
                title: ProfileTaggedMediaPresentation.destinationTileTitle,
                subtitle: taggedMediaCountLabel,
                systemImage: "photo.on.rectangle.angled",
                accessibilityIdentifier: "Profile.TaggedMediaLink"
            ) {
                ProfileTaggedMediaView()
            }

            profileDestinationTile(
                title: "Trips",
                subtitle: tripCountLabel,
                systemImage: TripPlannerPresentation.exploreChromeSystemImage,
                accessibilityIdentifier: "Profile.TripsLink",
                onTap: openTripPlanner
            ) {
                TripPlannerView()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func profileDestinationTile<Destination: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        accessibilityIdentifier: String,
        onTap: (() -> Void)? = nil,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    profileDestinationTileLabel(
                        title: title,
                        subtitle: subtitle,
                        systemImage: systemImage
                    )
                }
            } else {
                NavigationLink {
                    destination()
                } label: {
                    profileDestinationTileLabel(
                        title: title,
                        subtitle: subtitle,
                        systemImage: systemImage
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func profileDestinationTileLabel(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(
                    .system(
                        size: ProfileDestinationTilePresentation.iconPointSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(
                    width: ProfileDestinationTilePresentation.iconSlotWidth,
                    height: ProfileDestinationTilePresentation.iconSlotWidth
                )
                .accessibilityHidden(true)

            VStack(
                alignment: .leading,
                spacing: ProfileDestinationTilePresentation.textStackSpacing
            ) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, ProfileDestinationTilePresentation.horizontalPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: ProfileDestinationTilePresentation.tileHeight,
            maxHeight: ProfileDestinationTilePresentation.tileHeight,
            alignment: .leading
        )
        .background {
            RoundedRectangle(
                cornerRadius: ProfileDestinationTilePresentation.cornerRadius,
                style: .continuous
            )
            .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: ProfileDestinationTilePresentation.cornerRadius,
                style: .continuous
            )
            .strokeBorder(AppTheme.Colors.accentDeep.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
    }

    private var signOutButton: some View {
        Button("Sign out", role: .destructive) {
            showsSignOutConfirmation = true
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
