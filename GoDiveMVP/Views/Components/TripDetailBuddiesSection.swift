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
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .accessibilityIdentifier("TripDetail.Buddies.Empty")
            } else {
                LazyVGrid(columns: columns, spacing: TripDetailBuddiesPresentation.gridSpacing) {
                    ForEach(visibleBuddies) { buddy in
                        buddyCell(for: buddy)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
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
        VStack(spacing: AppTheme.Spacing.sm) {
            ProfileAvatarView(
                profilePhoto: rosterBuddy?.profilePhoto,
                diameter: TripDetailBuddiesPresentation.avatarDiameter,
                iconFont: .title2
            )

            Text(summary.displayName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)

            Text(DiveTripPresentation.tripBuddyTaggedDiveCountLabel(count: summary.diveCount))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        "\(summary.displayName), \(DiveTripPresentation.tripBuddyTaggedDiveCountLabel(count: summary.diveCount))"
    }
}
