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

    @Bindable var trip: DiveTrip

    var onSaved: () -> Void = {}
    var onDeleted: () -> Void = {}

    @State private var form: DiveTripFormValues
    @State private var saveErrorMessage: String?
    @State private var deleteErrorMessage: String?
    @State private var showsDeleteConfirmation = false

    init(trip: DiveTrip, onSaved: @escaping () -> Void = {}, onDeleted: @escaping () -> Void = {}) {
        self.trip = trip
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _form = State(initialValue: DiveTripFormValues(from: trip))
    }

    private var ownerTrips: [DiveTrip] {
        guard let ownerID = accountSession.currentProfile?.id ?? trip.ownerProfileID else { return [] }
        return allTrips.filter { $0.ownerProfileID == ownerID }
    }

    private var canSaveTrip: Bool {
        form.canSave(existingOwnerTrips: ownerTrips, excludingTripID: trip.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                TripPlannerFormContent(
                    form: $form,
                    existingOwnerTrips: ownerTrips,
                    editingTripID: trip.id,
                    clearsListRowBackgrounds: true
                )

                Section {
                    Button("Delete trip", role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                    .accessibilityIdentifier("TripEditSheet.Delete")
                    .listRowBackground(Color.clear)
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
        guard canSaveTrip else { return }

        if let conflict = form.overlappingTrip(among: ownerTrips, excludingTripID: trip.id) {
            saveErrorMessage = DiveTripPresentation.overlappingTripMessage(displayTitle: conflict.displayTitle)
            return
        }

        form.apply(to: trip)

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
