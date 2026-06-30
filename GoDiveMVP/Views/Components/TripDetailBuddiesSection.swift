import SwiftUI

/// Buddies tagged on linked trip dives — 3-column avatar grid.
struct TripDetailBuddiesSection: View {
    let buddies: [DiveTripBuddySummary]
    let rosterBuddiesByID: [UUID: DiveBuddy]
    var ownerProfile: UserProfile?

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
        let cell = TripDetailBuddyGridCell(
            summary: summary,
            rosterBuddy: rosterBuddiesByID[summary.buddyID]
        )

        if let rosterBuddy = rosterBuddiesByID[summary.buddyID],
           DiveBuddySelfRepresentation.isSelfBuddy(rosterBuddy, owner: ownerProfile) {
            cell
                .accessibilityIdentifier("TripDetail.Buddies.\(summary.buddyID.uuidString)")
        } else if let rosterBuddy = rosterBuddiesByID[summary.buddyID] {
            NavigationLink {
                ViewDiveBuddyDetails(buddy: rosterBuddy)
                    .hidesBottomTabBarWhenPushed()
            } label: {
                cell
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .accessibilityIdentifier("TripDetail.Buddies.\(summary.buddyID.uuidString)")
        } else {
            cell
                .accessibilityIdentifier("TripDetail.Buddies.\(summary.buddyID.uuidString)")
        }
    }
}

private struct TripDetailBuddyGridCell: View {
    let summary: DiveTripBuddySummary
    let rosterBuddy: DiveBuddy?

    var body: some View {
        TripDetailBuddyAvatarGridCell(
            profilePhoto: rosterBuddy?.profilePhoto,
            displayName: summary.displayName,
            subtitle: DiveTripPresentation.tripBuddyTaggedDiveCountLabel(count: summary.diveCount)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        "\(summary.displayName), \(DiveTripPresentation.tripBuddyTaggedDiveCountLabel(count: summary.diveCount))"
    }
}
