import SwiftData
import SwiftUI

/// Planned-trip buddies — same 3-column avatar grid as active trips, plus **Add buddy**.
struct TripDetailPlannedBuddiesSection: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var trip: DiveTrip
    let ownerProfile: UserProfile?

    @State private var showsAddBuddySheet = false

    private var plannedBuddies: [DiveBuddy] {
        DiveTripPlannedBuddyLinking.plannedBuddies(for: trip)
    }

    private var listMembers: [TripPlannedBuddyMember] {
        TripDetailPlannedBuddyPresentation.listMembers(
            owner: ownerProfile,
            plannedBuddies: plannedBuddies
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
    }

    @ViewBuilder
    private func plannedBuddyCell(for member: TripPlannedBuddyMember) -> some View {
        let cell = TripDetailPlannedBuddyGridCell(member: member)

        if member.isOwner {
            cell
                .accessibilityIdentifier("TripDetail.PlannedBuddies.Owner")
        } else if let buddy = plannedBuddies.first(where: { $0.id == member.id }),
                  !DiveBuddySelfRepresentation.isSelfBuddy(buddy, owner: ownerProfile) {
            NavigationLink {
                DiveBuddyOrFriendDetailView(buddy: buddy)
                    .hidesBottomTabBarWhenPushed()
            } label: {
                cell
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .accessibilityIdentifier("TripDetail.PlannedBuddies.\(member.id.uuidString)")
            .contextMenu {
                Button(role: .destructive) {
                    removeBuddy(buddy)
                } label: {
                    Label("Remove from trip", systemImage: "person.fill.xmark")
                }
            }
        } else {
            cell
                .accessibilityIdentifier("TripDetail.PlannedBuddies.\(member.id.uuidString)")
        }
    }

    private func removeBuddy(_ buddy: DiveBuddy) {
        DiveTripPlannedBuddyLinking.removeBuddy(buddy, from: trip, modelContext: modelContext)
        try? modelContext.save()
    }
}

private struct TripDetailPlannedBuddyGridCell: View {
    let member: TripPlannedBuddyMember

    var body: some View {
        TripDetailBuddyAvatarGridCell(
            profilePhoto: member.profilePhoto,
            displayName: member.displayName,
            subtitle: TripDetailPlannedBuddyPresentation.subtitle(for: member)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(member.displayName), \(TripDetailPlannedBuddyPresentation.subtitle(for: member))"
        )
    }
}
