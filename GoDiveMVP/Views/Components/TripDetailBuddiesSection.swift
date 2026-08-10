import SwiftUI

/// Buddies tagged on linked trip dives — 3-column avatar grid.
struct TripDetailBuddiesSection: View {
    let buddies: [DiveTripBuddySummary]
    let rosterBuddiesByID: [UUID: DiveBuddy]
    var ownerProfile: UserProfile?
    /// When set, shows share status (**Invited** / **Joined** / **Invite**) for GoDive friends.
    var trip: DiveTrip? = nil
    var onInviteFriend: ((DiveBuddy, String) -> Void)? = nil

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: TripDetailBuddiesPresentation.gridSpacing),
            count: TripDetailBuddiesPresentation.gridColumnCount
        )
    }

    private var visibleBuddies: [DiveTripBuddySummary] {
        buddies.filter { summary in
            guard let rosterBuddy = rosterBuddiesByID[summary.buddyID] else { return true }
            return !DiveBuddySelfRepresentation.isSelfBuddy(rosterBuddy, owner: ownerProfile)
        }
    }

    var body: some View {
        Group {
            if visibleBuddies.isEmpty {
                Text(DiveTripPresentation.tripBuddiesEmptyMessage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("TripDetail.Buddies.Empty")
            } else {
                LazyVGrid(columns: columns, alignment: .center, spacing: TripDetailBuddiesPresentation.gridSpacing) {
                    ForEach(visibleBuddies) { buddy in
                        buddyCell(for: buddy)
                    }
                }
                .accessibilityIdentifier("TripDetail.Buddies.List")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("TripDetail.BuddiesSection")
    }

    @ViewBuilder
    private func buddyCell(for summary: DiveTripBuddySummary) -> some View {
        let rosterBuddy = rosterBuddiesByID[summary.buddyID]
        let chrome = TripDetailPlannedBuddyPresentation.shareChrome(
            forRosterBuddy: rosterBuddy,
            trip: trip
        )
        let inviteAction: (() -> Void)? = {
            guard chrome == .invite,
                  let rosterBuddy,
                  let uid = DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: rosterBuddy),
                  let onInviteFriend
            else { return nil }
            return { onInviteFriend(rosterBuddy, uid) }
        }()
        let badge = TripDetailPlannedBuddyPresentation.statusBadgeTitle(for: chrome)

        let identity = TripDetailBuddyAvatarGridCell(
            profilePhoto: rosterBuddy?.profilePhoto,
            displayName: summary.displayName,
            showsGoDiveUserPin: rosterBuddy.map(DiveBuddyFriendLinkPresentation.isLinkedFriend) ?? false,
            showsStatusRow: false
        )

        let chromeView = TripBuddyStatusChrome(
            statusBadgeTitle: badge,
            inviteAction: inviteAction
        )

        if let rosterBuddy,
           DiveBuddySelfRepresentation.isSelfBuddy(rosterBuddy, owner: ownerProfile) {
            VStack(spacing: AppTheme.Spacing.sm) {
                identity
                chromeView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(summary: summary, chrome: chrome, rosterBuddy: rosterBuddy))
            .accessibilityIdentifier("TripDetail.Buddies.\(summary.buddyID.uuidString)")
        } else if let rosterBuddy {
            VStack(spacing: AppTheme.Spacing.sm) {
                NavigationLink {
                    DiveBuddyOrFriendDetailView(buddy: rosterBuddy)
                        .hidesBottomTabBarWhenPushed()
                } label: {
                    identity
                }
                .buttonStyle(.plain)
                .navigationLinkIndicatorVisibility(.hidden)

                chromeView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(summary: summary, chrome: chrome, rosterBuddy: rosterBuddy))
            .accessibilityIdentifier("TripDetail.Buddies.\(summary.buddyID.uuidString)")
        } else {
            VStack(spacing: AppTheme.Spacing.sm) {
                identity
                chromeView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(summary: summary, chrome: chrome, rosterBuddy: nil))
            .accessibilityIdentifier("TripDetail.Buddies.\(summary.buddyID.uuidString)")
        }
    }

    private func accessibilityLabel(
        summary: DiveTripBuddySummary,
        chrome: TripBuddyTripShareChrome,
        rosterBuddy: DiveBuddy?
    ) -> String {
        var parts = [summary.displayName]
        if let caption = TripDetailPlannedBuddyPresentation.accessibilityCaption(for: chrome) {
            parts.append(caption)
        } else {
            parts.append(
                DiveTripPresentation.tripBuddyTaggedDiveCountLabel(count: summary.diveCount)
            )
        }
        if let rosterBuddy, DiveBuddyFriendLinkPresentation.isLinkedFriend(rosterBuddy) {
            parts.append(GoDiveUserAvatarPinPresentation.accessibilityLabel)
        }
        return parts.joined(separator: ", ")
    }
}
