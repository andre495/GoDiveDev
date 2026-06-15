import SwiftData
import SwiftUI

/// Sheet form to create a new **`DiveTrip`** for the signed-in profile.
struct TripAddSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    var onSaved: () -> Void = {}

    @State private var form = DiveTripFormValues()
    @State private var saveErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TripPlannerFormContent(form: $form)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(TripPlannerPresentation.newTripSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("TripAddSheet.Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTrip()
                    }
                    .fontWeight(.semibold)
                    .disabled(!form.canSave)
                    .accessibilityIdentifier("TripAddSheet.Save")
                }
            }
            .alert("Could not save", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Try again.")
            }
        }
        .tripPlannerAddSheetPresentation()
        .accessibilityIdentifier("TripAddSheet.Root")
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private func saveTrip() {
        guard form.canSave else { return }
        guard let profile = accountSession.currentProfile else {
            saveErrorMessage = "Sign in to save a trip."
            return
        }

        let trip = form.makeDiveTrip(plannedSites: [])
        DiveTripOwnership.assignOwner(profile, to: trip)
        modelContext.insert(trip)

        do {
            let activities = try DiveActivityOwnership.activities(
                forOwnerProfileID: profile.id,
                modelContext: modelContext
            )
            _ = DiveTripActivityLinking.applyAutoLink(
                to: trip,
                activities: activities,
                modelContext: modelContext
            )
            try modelContext.save()
            DiveTripLogbookSync.notifyGroupingDidChange()
            onSaved()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Form

struct TripPlannerFormContent: View {
    @Binding var form: DiveTripFormValues

    var body: some View {
        Section {
            TextField("Trip name", text: $form.title, prompt: Text("e.g. Bonaire 2026"))
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("TripPlanner.Title")

            DatePicker(
                "Start date",
                selection: $form.startDate,
                displayedComponents: .date
            )
            .accessibilityIdentifier("TripPlanner.StartDate")

            DatePicker(
                "End date",
                selection: $form.endDate,
                displayedComponents: .date
            )
            .accessibilityIdentifier("TripPlanner.EndDate")
        } footer: {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                if !form.hasValidDateRange {
                    Text(DiveTripPresentation.invalidDateRangeMessage)
                        .foregroundStyle(Color.red)
                }
                Text("Give your trip a name, a destination, or both.")
            }
        }

        Section {
            TextField(
                "Countries",
                text: $form.countriesText,
                prompt: Text("e.g. Bonaire, Curaçao")
            )
            .textInputAutocapitalization(.words)
            .accessibilityIdentifier("TripPlanner.Countries")
        } footer: {
            Text("Separate multiple countries with commas.")
        }
    }
}

#Preview {
    TripAddSheetView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
