import SwiftData
import SwiftUI

/// Sheet form to edit an existing **`DiveTrip`**.
struct TripEditSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @Query(
        sort: [
            SortDescriptor(\DiveTrip.startDate, order: .reverse),
            SortDescriptor(\DiveTrip.createdAt, order: .reverse),
        ]
    )
    private var allTrips: [DiveTrip]

    @Query private var ownedBuddies: [DiveBuddy]

    @Bindable var trip: DiveTrip

    var onSaved: () -> Void = {}
    var onDeleted: () -> Void = {}

    @State private var form: DiveTripFormValues
    @State private var selectedBuddyIDs: Set<UUID>
    @State private var showsBuddyPicker = false
    @State private var showsCountryPicker = false
    @State private var saveErrorMessage: String?
    @State private var deleteErrorMessage: String?
    @State private var showsDeleteConfirmation = false
    @FocusState private var isTitleFocused: Bool

    init(trip: DiveTrip, onSaved: @escaping () -> Void = {}, onDeleted: @escaping () -> Void = {}) {
        self.trip = trip
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _form = State(initialValue: DiveTripFormValues(from: trip))
        _selectedBuddyIDs = State(initialValue: DiveTripPlannedBuddyDraftPresentation.plannedBuddyIDs(on: trip))
        let filterOwnerID = trip.ownerProfileID ?? Self.noOwnerQueryToken
        _ownedBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
        )
    }

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var ownerTrips: [DiveTrip] {
        guard let ownerID = accountSession.currentProfile?.id ?? trip.ownerProfileID else { return [] }
        return allTrips.filter { $0.ownerProfileID == ownerID }
    }

    private var canSaveTrip: Bool {
        form.canSave(existingOwnerTrips: ownerTrips, excludingTripID: trip.id)
    }

    private var rosterByID: [UUID: DiveBuddy] {
        DiveTripPlannedBuddyDraftPresentation.rosterByID(
            ownedBuddies: ownedBuddies,
            selectedBuddyIDs: selectedBuddyIDs,
            modelContext: modelContext
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                TripPlannerFormContent(
                    form: $form,
                    selectedBuddyIDs: $selectedBuddyIDs,
                    ownedBuddies: ownedBuddies,
                    existingOwnerTrips: ownerTrips,
                    editingTripID: trip.id,
                    isTitleFocused: $isTitleFocused,
                    addCountriesAccessibilityIdentifier: TripPlannerPresentation.editTripCountriesAccessibilityIdentifier,
                    addBuddiesAccessibilityIdentifier: TripPlannerPresentation.editTripBuddiesAccessibilityIdentifier,
                    onAddCountries: {
                        isTitleFocused = false
                        showsCountryPicker = true
                    },
                    onAddBuddies: {
                        isTitleFocused = false
                        showsBuddyPicker = true
                    }
                )

                Section {
                    Button("Delete trip", role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("TripEditSheet.Delete")
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: TripPlannerPresentation.editTripCancelAccessibilityIdentifier
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: saveChanges,
                        accessibilityIdentifier: TripPlannerPresentation.editTripDoneAccessibilityIdentifier,
                        isEnabled: canSaveTrip
                    )
                }
            }
            .alert("Could not save", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Try again.")
            }
            .alert("Could not delete trip", isPresented: deleteErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteErrorMessage ?? "Try again.")
            }
            .confirmationDialog(
                TripPlannerPresentation.deleteTripConfirmationTitle,
                isPresented: $showsDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete trip", role: .destructive) {
                    deleteTrip()
                }
            } message: {
                Text(TripPlannerPresentation.deleteTripConfirmationMessage(displayTitle: trip.displayTitle))
            }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .sheet(isPresented: $showsCountryPicker) {
            TripCountryPickerSheet(selectedCountries: $form.selectedCountries)
        }
        .sheet(isPresented: $showsBuddyPicker) {
            TripPlannedBuddyPickerSheet(
                selectedBuddyIDs: $selectedBuddyIDs,
                ownerProfileID: accountSession.currentProfile?.id ?? trip.ownerProfileID
            )
        }
        .accessibilityIdentifier("TripEditSheet.Root")
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private var deleteErrorBinding: Binding<Bool> {
        Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )
    }

    private func saveChanges() {
        isTitleFocused = false
        guard canSaveTrip else { return }

        if let conflict = form.overlappingTrip(among: ownerTrips, excludingTripID: trip.id) {
            saveErrorMessage = DiveTripPresentation.overlappingTripMessage(displayTitle: conflict.displayTitle)
            return
        }

        form.apply(to: trip)

        DiveTripPlannedBuddyDraftPresentation.apply(
            draftBuddyIDs: selectedBuddyIDs,
            to: trip,
            rosterByID: rosterByID,
            modelContext: modelContext
        )

        do {
            if let ownerID = accountSession.currentProfile?.id ?? trip.ownerProfileID {
                let activities = try DiveActivityOwnership.activities(
                    forOwnerProfileID: ownerID,
                    modelContext: modelContext
                )
                _ = DiveTripActivityLinking.applyAutoLink(
                    to: trip,
                    activities: activities,
                    modelContext: modelContext
                )
            }
            try modelContext.save()
            DiveTripLogbookSync.notifyGroupingDidChange()
            let savedTrip = trip
            Task { @MainActor in
                await DiveTripReminderScheduler.reschedule(for: savedTrip)
            }
            onSaved()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func deleteTrip() {
        do {
            try DiveTripDeletion.deletePermanently(trip, modelContext: modelContext)
            onDeleted()
            dismiss()
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
    }
}
