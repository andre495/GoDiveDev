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

    @Query private var ownedCertifications: [Certification]
    @Query private var ownedEquipment: [EquipmentItem]
    @Query private var ownedDiveActivities: [DiveActivity]
    @Query private var ownedDiveBuddies: [DiveBuddy]
    @Query private var ownedTrips: [DiveTrip]

    @Query(sort: [SortDescriptor(\DiveMediaBuddyTag.id, order: .forward)])
    private var buddyMediaTags: [DiveMediaBuddyTag]

    @State private var showsProfileEditSheet = false
    @State private var showsSignOutConfirmation = false
    @State private var selfBuddyID: UUID?

    private let ownerProfileID: UUID?

    init(ownerProfileID: UUID?) {
        self.ownerProfileID = ownerProfileID
        let filterOwnerID = ownerProfileID ?? Self.noOwnerQueryToken
        _ownedCertifications = Query(
            filter: #Predicate<Certification> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\Certification.dateAttained, order: .reverse)]
        )
        _ownedEquipment = Query(
            filter: #Predicate<EquipmentItem> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\EquipmentItem.manufacturer, order: .forward),
                SortDescriptor(\EquipmentItem.model, order: .forward),
            ]
        )
        _ownedDiveActivities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveActivity.startTime, order: .reverse),
                SortDescriptor(\DiveActivity.id, order: .forward),
            ]
        )
        _ownedDiveBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
        )
        _ownedTrips = Query(
            filter: #Predicate<DiveTrip> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveTrip.startDate, order: .reverse),
                SortDescriptor(\DiveTrip.createdAt, order: .reverse),
            ]
        )
    }

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var ownedCertificationsFiltered: [Certification] {
        ownedCertifications
    }

    private var ownedEquipmentFiltered: [EquipmentItem] {
        ownedEquipment
    }

    private var ownedDiveBuddiesFiltered: [DiveBuddy] {
        DiveBuddySelfRepresentation.rosterBuddiesExcludingSelf(
            ownedDiveBuddies,
            owner: accountSession.currentProfile
        )
    }

    private var ownedTripsFiltered: [DiveTrip] {
        ownedTrips
    }

    private var certificationCountLabel: String {
        ProfilePresentation.certificationCountLabel(ownedCertificationsFiltered.count)
    }

    private var equipmentItemCountLabel: String {
        ProfilePresentation.equipmentItemCountLabel(ownedEquipmentFiltered.count)
    }

    private var diveBuddyCountLabel: String {
        ProfilePresentation.diveBuddyRosterCountLabel(ownedDiveBuddiesFiltered.count)
    }

    private var tripCountLabel: String {
        ProfilePresentation.tripCountLabel(ownedTripsFiltered.count)
    }

    private var profileFeaturedCertification: CertificationPresentation.ProfileFeaturedCertificationDisplay? {
        CertificationPresentation.profileFeaturedCertification(from: ownedCertificationsFiltered)
    }

    private var featuredCertificationCard: Certification? {
        CertificationPresentation.profileFeaturedCertificationCard(from: ownedCertificationsFiltered)
    }

    private var ownedDiveActivityCount: Int {
        ownedDiveActivities.count
    }

    private var diveCountLabel: String {
        ProfilePresentation.diveActivityCountLabel(ownedDiveActivityCount)
    }

    private var ownerDiveActivityIDs: Set<UUID> {
        Set(ownedDiveActivities.map(\.id))
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
                DiveBuddiesListView(ownerProfileID: ownerProfileID)
            }

            profileDestinationTile(
                title: ProfileTaggedMediaPresentation.destinationTileTitle,
                subtitle: taggedMediaCountLabel,
                systemImage: "photo.on.rectangle.angled",
                accessibilityIdentifier: "Profile.TaggedMediaLink"
            ) {
                ProfileTaggedMediaView(ownerProfileID: ownerProfileID)
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
        ProfileView(ownerProfileID: nil)
    }
    .environment(AccountSession.shared)
    .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
