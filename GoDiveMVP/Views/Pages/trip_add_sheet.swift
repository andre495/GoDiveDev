import SwiftData
import SwiftUI

/// Sheet form to create a new **`DiveTrip`** for the signed-in profile.
struct TripAddSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @Query private var ownerTrips: [DiveTrip]

    var onSaved: () -> Void = {}

    @State private var form = DiveTripFormValues()
    @State private var saveErrorMessage: String?

    init(ownerProfileID: UUID? = nil, onSaved: @escaping () -> Void = {}) {
        self.onSaved = onSaved
        let filterOwnerID = ownerProfileID ?? Self.noOwnerQueryToken
        _ownerTrips = Query(
            filter: #Predicate<DiveTrip> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveTrip.startDate, order: .reverse),
                SortDescriptor(\DiveTrip.createdAt, order: .reverse),
            ]
        )
    }

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var canSaveTrip: Bool {
        form.canSave(existingOwnerTrips: ownerTrips)
    }

    var body: some View {
        NavigationStack {
            Form {
                TripPlannerFormContent(
                    form: $form,
                    existingOwnerTrips: ownerTrips,
                    clearsListRowBackgrounds: true
                )
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: TripPlannerPresentation.addTripCancelAccessibilityIdentifier
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: saveTrip,
                        accessibilityIdentifier: TripPlannerPresentation.addTripDoneAccessibilityIdentifier,
                        isEnabled: canSaveTrip
                    )
                }
            }
            .alert("Could not save", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Try again.")
            }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .accessibilityIdentifier("TripAddSheet.Root")
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private func saveTrip() {
        guard canSaveTrip else { return }
        guard let profile = accountSession.currentProfile else {
            saveErrorMessage = "Sign in to save a trip."
            return
        }

        if let conflict = form.overlappingTrip(among: ownerTrips) {
            saveErrorMessage = DiveTripPresentation.overlappingTripMessage(displayTitle: conflict.displayTitle)
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
    var existingOwnerTrips: [DiveTrip] = []
    var editingTripID: UUID? = nil
    /// Blue overview-panel modals clear Form card fills so rows sit on the presentation background.
    var clearsListRowBackgrounds: Bool = false

    private var overlappingTrip: DiveTrip? {
        form.overlappingTrip(among: existingOwnerTrips, excludingTripID: editingTripID)
    }

    var body: some View {
        Section {
            TextField("Trip name", text: $form.title, prompt: Text("e.g. Bonaire 2026"))
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("TripPlanner.Title")
                .modifier(TripPlannerFormListRowBackground(clears: clearsListRowBackgrounds))

            DatePicker(
                "Start date",
                selection: $form.startDate,
                displayedComponents: .date
            )
            .accessibilityIdentifier("TripPlanner.StartDate")
            .modifier(TripPlannerFormListRowBackground(clears: clearsListRowBackgrounds))

            DatePicker(
                "End date",
                selection: $form.endDate,
                displayedComponents: .date
            )
            .accessibilityIdentifier("TripPlanner.EndDate")
            .modifier(TripPlannerFormListRowBackground(clears: clearsListRowBackgrounds))
        } footer: {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                if !form.hasValidDateRange {
                    Text(DiveTripPresentation.invalidDateRangeMessage)
                        .foregroundStyle(Color.red)
                } else if let overlappingTrip {
                    Text(DiveTripPresentation.overlappingTripMessage(displayTitle: overlappingTrip.displayTitle))
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
            .modifier(TripPlannerFormListRowBackground(clears: clearsListRowBackgrounds))
        } footer: {
            Text("Separate multiple countries with commas.")
        }
    }
}

private struct TripPlannerFormListRowBackground: ViewModifier {
    let clears: Bool

    func body(content: Content) -> some View {
        if clears {
            content.listRowBackground(Color.clear)
        } else {
            content
        }
    }
}

#Preview {
    TripAddSheetView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
