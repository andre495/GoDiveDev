import SwiftData
import SwiftUI

/// Sheet form to edit an existing **`DiveTrip`**.
struct TripEditSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @Bindable var trip: DiveTrip

    @Query(sort: \DiveSite.siteName) private var diveSites: [DiveSite]

    var onSaved: () -> Void = {}
    var onDeleted: () -> Void = {}

    @State private var form: DiveTripFormValues
    @State private var showsPlannedSitePicker = false
    @State private var saveErrorMessage: String?
    @State private var deleteErrorMessage: String?
    @State private var showsDeleteConfirmation = false

    init(trip: DiveTrip, onSaved: @escaping () -> Void = {}, onDeleted: @escaping () -> Void = {}) {
        self.trip = trip
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _form = State(initialValue: DiveTripFormValues(from: trip))
    }

    var body: some View {
        NavigationStack {
            Form {
                TripPlannerFormContent(
                    form: $form,
                    showsPlannedSitePicker: $showsPlannedSitePicker
                )

                Section {
                    Button("Delete trip", role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                    .accessibilityIdentifier("TripEditSheet.Delete")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(TripPlannerPresentation.editTripSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("TripEditSheet.Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(!form.canSave)
                    .accessibilityIdentifier("TripEditSheet.Save")
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
        .sheet(isPresented: $showsPlannedSitePicker) {
            TripPlannedSitePickerSheet(
                selectedSiteIDs: $form.plannedSiteIDs,
                sites: diveSites
            )
        }
        .tripPlannerAddSheetPresentation()
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
        guard form.canSave else { return }

        let plannedSites = diveSites.filter { form.plannedSiteIDs.contains($0.id) }
        form.apply(to: trip, plannedSites: plannedSites)

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
