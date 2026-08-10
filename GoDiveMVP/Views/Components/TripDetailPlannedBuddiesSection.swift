import SwiftData
import SwiftUI

/// Planned-trip buddies — same 3-column avatar grid as active trips, plus **Add buddy**.
struct TripDetailPlannedBuddiesSection: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var trip: DiveTrip
    let ownerProfile: UserProfile?

    @State private var showsAddBuddySheet = false
    @State private var shareOfferQueue = DiveTripShareOfferQueue()

    private var plannedBuddies: [DiveBuddy] {
        DiveTripPlannedBuddyLinking.plannedBuddies(for: trip)
    }

    private var listMembers: [TripPlannedBuddyMember] {
        TripDetailPlannedBuddyPresentation.listMembers(
            owner: ownerProfile,
            plannedBuddies: plannedBuddies,
            trip: trip
        )
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: TripDetailBuddiesPresentation.gridSpacing),
            count: TripDetailBuddiesPresentation.gridColumnCount
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if DiveTripShareLineagePresentation.canEditSharedDetails(trip) {
                Button {
                    showsAddBuddySheet = true
                } label: {
                    Label(
                        DiveTripPresentation.addPlannedBuddyButtonTitle,
                        systemImage: "plus"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.accent)
                .accessibilityIdentifier("TripDetail.PlannedBuddies.Add")
            }

            if listMembers.isEmpty {
                Text(DiveTripPresentation.tripBuddiesPlannedEmptyMessage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("TripDetail.PlannedBuddies.Empty")
            } else {
                LazyVGrid(columns: columns, alignment: .center, spacing: TripDetailBuddiesPresentation.gridSpacing) {
                    ForEach(listMembers) { member in
                        plannedBuddyCell(for: member)
                    }
                }
                .accessibilityIdentifier("TripDetail.PlannedBuddies.List")

                if plannedBuddies.isEmpty {
                    Text(DiveTripPresentation.tripBuddiesPlannedEmptyMessage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("TripDetail.PlannedBuddiesSection")
        .sheet(isPresented: $showsAddBuddySheet) {
            TripPlannedBuddyPickerSheet(trip: trip)
        }
        .alert(
            shareOfferQueue.current.map {
                DiveTripShareOfferPresentation.confirmationTitle(displayName: $0.displayName)
            } ?? "",
            isPresented: DiveTripShareOfferAlertModifier.alertBinding(queue: shareOfferQueue)
        ) {
            Button(DiveTripShareOfferPresentation.shareButtonTitle) {
                shareOfferQueue.share(modelContext: modelContext)
            }
            Button(DiveTripShareOfferPresentation.declineButtonTitle, role: .cancel) {
                shareOfferQueue.decline()
            }
        } message: {
            Text(DiveTripShareOfferPresentation.confirmationMessage)
        }
    }

    @ViewBuilder
    private func plannedBuddyCell(for member: TripPlannedBuddyMember) -> some View {
        let inviteAction = inviteAction(for: member)
        let subtitle = TripDetailPlannedBuddyPresentation.subtitle(for: member)
        let badge = TripDetailPlannedBuddyPresentation.statusBadgeTitle(for: member)

        let identity = TripDetailBuddyAvatarGridCell(
            profilePhoto: member.profilePhoto,
            displayName: member.displayName,
            showsGoDiveUserPin: member.showsGoDiveUserPin,
            showsStatusRow: false
        )

        let stack = VStack(spacing: AppTheme.Spacing.sm) {
            identity
            TripBuddyStatusChrome(
                subtitle: subtitle,
                statusBadgeTitle: badge,
                inviteAction: inviteAction
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: member))

        if member.isOwner {
            stack
                .accessibilityIdentifier("TripDetail.PlannedBuddies.Owner")
        } else if let buddy = plannedBuddies.first(where: { $0.id == member.id }),
                  !DiveBuddySelfRepresentation.isSelfBuddy(buddy, owner: ownerProfile) {
            VStack(spacing: AppTheme.Spacing.sm) {
                NavigationLink {
                    DiveBuddyOrFriendDetailView(buddy: buddy)
                        .hidesBottomTabBarWhenPushed()
                } label: {
                    identity
                }
                .buttonStyle(.plain)
                .navigationLinkIndicatorVisibility(.hidden)

                TripBuddyStatusChrome(
                    subtitle: subtitle,
                    statusBadgeTitle: badge,
                    inviteAction: inviteAction
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(for: member))
            .accessibilityIdentifier("TripDetail.PlannedBuddies.\(member.id.uuidString)")
            .contextMenu {
                Button(role: .destructive) {
                    removeBuddy(buddy)
                } label: {
                    Label("Remove from trip", systemImage: "person.fill.xmark")
                }
            }
        } else {
            stack
                .accessibilityIdentifier("TripDetail.PlannedBuddies.\(member.id.uuidString)")
        }
    }

    private func inviteAction(for member: TripPlannedBuddyMember) -> (() -> Void)? {
        guard member.shareChrome == .invite,
              DiveTripShareLineagePresentation.canEditSharedDetails(trip),
              let buddy = plannedBuddies.first(where: { $0.id == member.id }),
              let friendUID = DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: buddy)
        else { return nil }
        return {
            promptShareInvite(buddy: buddy, friendUID: friendUID)
        }
    }

    private func accessibilityLabel(for member: TripPlannedBuddyMember) -> String {
        var parts = [member.displayName]
        if let caption = TripDetailPlannedBuddyPresentation.accessibilityCaption(for: member.shareChrome) {
            parts.append(caption)
        }
        if member.showsGoDiveUserPin {
            parts.append(GoDiveUserAvatarPinPresentation.accessibilityLabel)
        }
        return parts.joined(separator: ", ")
    }

    private func promptShareInvite(buddy: DiveBuddy, friendUID: String) {
        let candidate = DiveTripShareOfferPresentation.Candidate(
            buddyID: buddy.id,
            friendUID: friendUID,
            displayName: buddy.displayName
        )
        shareOfferQueue.enqueue(candidates: [candidate], for: trip)
    }

    private func removeBuddy(_ buddy: DiveBuddy) {
        DiveTripPlannedBuddyLinking.removeBuddy(buddy, from: trip, modelContext: modelContext)
        try? modelContext.save()
        if let friendUID = DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: buddy) {
            let savedTrip = trip
            Task { @MainActor in
                await GoDiveTripShareSync.revokeShares(for: savedTrip, friendUIDs: [friendUID])
                try? modelContext.save()
            }
        }
    }
}
