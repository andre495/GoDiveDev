import SwiftData
import SwiftUI

/// Pick roster buddies to invite on a planned trip (blue overview-panel modal).
struct TripPlannedBuddyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var trip: DiveTrip

    @Query private var ownedBuddies: [DiveBuddy]

    @State private var showsAddBuddySheet = false
    @State private var draftBuddyIDs: Set<UUID> = []
    @State private var draftRosterOverrides: [UUID: DiveBuddy] = [:]

    init(trip: DiveTrip) {
        self._trip = Bindable(wrappedValue: trip)
        let filterOwnerID = trip.ownerProfileID
        _ownedBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
        )
    }

    private var rosterByID: [UUID: DiveBuddy] {
        var map = Dictionary(uniqueKeysWithValues: ownedBuddies.map { ($0.id, $0) })
        for (id, buddy) in draftRosterOverrides {
            map[id] = buddy
        }
        return map
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
                            .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(ownedBuddies, id: \.id) { buddy in
                            Button {
                                toggleBuddy(buddy)
                            } label: {
                                TripPlannedBuddyPickerRow(
                                    buddy: buddy,
                                    isOnTrip: draftBuddyIDs.contains(buddy.id)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: DiveTripPresentation.plannedBuddyPickerCancelAccessibilityIdentifier
                    )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    AppSheetToolbarPlusButton(
                        action: { showsAddBuddySheet = true },
                        accessibilityIdentifier: DiveTripPresentation.plannedBuddyPickerAddBuddyAccessibilityIdentifier,
                        accessibilityLabel: DiveTripPresentation.addPlannedBuddyAccessibilityLabel
                    )
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: {
                            commitDraftBuddies()
                            dismiss()
                        },
                        accessibilityIdentifier: DiveTripPresentation.plannedBuddyPickerDoneAccessibilityIdentifier
                    )
                }
            }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .onAppear(perform: reloadDraftBuddyIDs)
        .sheet(isPresented: $showsAddBuddySheet) {
            DiveActivityAddBuddySheet { buddy in
                draftRosterOverrides[buddy.id] = buddy
                draftBuddyIDs.insert(buddy.id)
            }
        }
        .accessibilityIdentifier("TripPlannedBuddyPicker.Root")
    }

    private func reloadDraftBuddyIDs() {
        draftBuddyIDs = DiveTripPlannedBuddyDraftPresentation.plannedBuddyIDs(on: trip)
    }

    private func toggleBuddy(_ buddy: DiveBuddy) {
        if draftBuddyIDs.contains(buddy.id) {
            draftBuddyIDs.remove(buddy.id)
        } else {
            draftBuddyIDs.insert(buddy.id)
        }
    }

    private func commitDraftBuddies() {
        DiveTripPlannedBuddyDraftPresentation.apply(
            draftBuddyIDs: draftBuddyIDs,
            to: trip,
            rosterByID: rosterByID,
            modelContext: modelContext
        )
        try? modelContext.save()
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
                iconFont: .callout,
                placeholderInitials: DiveBuddyPresentation.initials(from: buddy.displayName)
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
