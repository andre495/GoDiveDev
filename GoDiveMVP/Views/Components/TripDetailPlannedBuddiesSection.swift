import SwiftData
import SwiftUI

/// Planned-trip buddies — owner, invited roster buddies, and add action.
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

            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(listMembers) { member in
                    if member.isOwner {
                        TripDetailPlannedBuddyMemberRow(member: member)
                            .accessibilityIdentifier("TripDetail.PlannedBuddies.Owner")
                    } else if let buddy = plannedBuddies.first(where: { $0.id == member.id }) {
                        TripDetailPlannedBuddyMemberRow(member: member)
                            .accessibilityIdentifier("TripDetail.PlannedBuddies.\(member.id.uuidString)")
                            .contextMenu {
                                Button(role: .destructive) {
                                    removeBuddy(buddy)
                                } label: {
                                    Label("Remove from trip", systemImage: "person.fill.xmark")
                                }
                            }
                    }
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        )
        .accessibilityIdentifier("TripDetail.PlannedBuddiesSection")
        .sheet(isPresented: $showsAddBuddySheet) {
            TripPlannedBuddyPickerSheet(trip: trip)
        }
    }

    private func removeBuddy(_ buddy: DiveBuddy) {
        DiveTripPlannedBuddyLinking.removeBuddy(buddy, from: trip, modelContext: modelContext)
        try? modelContext.save()
    }
}

private struct TripDetailPlannedBuddyMemberRow: View {
    let member: TripPlannedBuddyMember

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ProfileAvatarView(
                profilePhoto: member.profilePhoto,
                diameter: 48,
                iconFont: .title3
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(member.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)

                Text(TripDetailPlannedBuddyPresentation.subtitle(for: member))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceMuted.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.Colors.tabUnselected.opacity(0.14), lineWidth: 1)
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(member.displayName), \(TripDetailPlannedBuddyPresentation.subtitle(for: member))"
        )
    }
}
