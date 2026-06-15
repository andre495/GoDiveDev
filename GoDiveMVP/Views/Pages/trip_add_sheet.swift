import SwiftData
import SwiftUI

/// Sheet form to create a new **`DiveTrip`** for the signed-in profile.
struct TripAddSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @Query(sort: \DiveSite.siteName) private var diveSites: [DiveSite]

    var onSaved: () -> Void = {}

    @State private var form = DiveTripFormValues()
    @State private var showsPlannedSitePicker = false
    @State private var saveErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TripPlannerFormContent(
                    form: $form,
                    showsPlannedSitePicker: $showsPlannedSitePicker
                )
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
        .sheet(isPresented: $showsPlannedSitePicker) {
            TripPlannedSitePickerSheet(
                selectedSiteIDs: $form.plannedSiteIDs,
                sites: diveSites
            )
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

        let plannedSites = diveSites.filter { form.plannedSiteIDs.contains($0.id) }
        let trip = form.makeDiveTrip(plannedSites: plannedSites)
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
    @Binding var showsPlannedSitePicker: Bool

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

        Section {
            Button {
                showsPlannedSitePicker = true
            } label: {
                HStack {
                    Text(DiveTripPresentation.plannedSitesSectionTitle)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer(minLength: 0)
                    Text(DiveTripPresentation.plannedSitesSummary(selectedCount: form.plannedSiteIDs.count))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
            .accessibilityIdentifier("TripPlanner.PlannedSites")
        }
    }
}

#Preview {
    TripAddSheetView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
