import SwiftData
import SwiftUI

/// Pick roster buddies to invite on a planned trip.
struct TripPlannedBuddyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @Bindable var trip: DiveTrip

    @Query(sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)])
    private var allBuddies: [DiveBuddy]

    @State private var showsAddBuddySheet = false

    private var ownerProfileID: UUID? {
        accountSession.currentProfile?.id
    }

    private var ownedBuddies: [DiveBuddy] {
        guard let ownerProfileID else { return [] }
        return allBuddies.filter { $0.ownerProfileID == ownerProfileID }
    }

    var body: some View {
        NavigationStack {
            List {
                if ownedBuddies.isEmpty {
                    Section {
                        Text(DiveTripPresentation.tripPlannedBuddyPickerEmptyRosterMessage)
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                            .accessibilityIdentifier("TripPlannedBuddyPicker.EmptyRoster")
                    }
                } else {
                    Section {
                        ForEach(ownedBuddies, id: \.id) { buddy in
                            Button {
                                toggleBuddy(buddy)
                            } label: {
                                TripPlannedBuddyPickerRow(
                                    buddy: buddy,
                                    isOnTrip: DiveTripPlannedBuddyLinking.isBuddyOnTrip(
                                        buddyID: buddy.id,
                                        trip: trip
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(
                                top: 0,
                                leading: AppTheme.Spacing.md,
                                bottom: 0,
                                trailing: AppTheme.Spacing.md
                            ))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("TripPlannedBuddyPicker.Row.\(buddy.id.uuidString)")
                        }
                    } header: {
                        Text("Your buddies")
                    } footer: {
                        Text(DiveTripPresentation.tripPlannedBuddyPickerFooter)
                    }
                }
            }
            .listStyle(.plain)
            .listRowSpacing(TripPlannedBuddyPickerRowLayout.listRowSpacing)
            .scrollContentBackground(.hidden)
            .navigationTitle(DiveTripPresentation.tripPlannedBuddyPickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showsAddBuddySheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.tabSelected)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(DiveTripPresentation.addPlannedBuddyAccessibilityLabel)
                    .accessibilityIdentifier("TripPlannedBuddyPicker.AddBuddy")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .accessibilityIdentifier("TripPlannedBuddyPicker.Done")
                }
            }
        }
        .diveActivityTagsSheetPresentation()
        .sheet(isPresented: $showsAddBuddySheet) {
            DiveActivityAddBuddySheet()
        }
        .accessibilityIdentifier("TripPlannedBuddyPicker.Root")
    }

    private func toggleBuddy(_ buddy: DiveBuddy) {
        DiveTripPlannedBuddyLinking.toggleBuddy(buddy, on: trip, modelContext: modelContext)
    }
}

// MARK: - Row

private enum TripPlannedBuddyPickerRowLayout {
    static let avatarDiameter: CGFloat = 36
    static let rowPadding = EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
    static let listRowSpacing: CGFloat = 6
    static let cornerRadius: CGFloat = 10
}

private struct TripPlannedBuddyPickerRow: View {
    let buddy: DiveBuddy
    let isOnTrip: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ProfileAvatarView(
                profilePhoto: buddy.profilePhoto,
                diameter: TripPlannedBuddyPickerRowLayout.avatarDiameter,
                iconFont: .callout
            )

            Text(buddy.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isOnTrip {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .accessibilityHidden(true)
            }
        }
        .padding(TripPlannedBuddyPickerRowLayout.rowPadding)
        .background(rowBackground)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isOnTrip ? "On this trip" : "Not on this trip")
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: TripPlannedBuddyPickerRowLayout.cornerRadius, style: .continuous)
            .fill(
                isOnTrip
                    ? AppTheme.Colors.tabSelected.opacity(0.14)
                    : AppTheme.Colors.surfaceElevated
            )
            .overlay {
                RoundedRectangle(cornerRadius: TripPlannedBuddyPickerRowLayout.cornerRadius, style: .continuous)
                    .stroke(
                        isOnTrip ? AppTheme.Colors.tabSelected.opacity(0.55) : Color.clear,
                        lineWidth: 1.5
                    )
            }
    }
}
