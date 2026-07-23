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
            TripPlannerSheetScrollContainer {
                TripPlannerFormContent(
                    form: $form,
                    existingOwnerTrips: ownerTrips
                )
            }
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

        let trip = form.makeDiveTrip()
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

    private var overlappingTrip: DiveTrip? {
        form.overlappingTrip(among: existingOwnerTrips, excludingTripID: editingTripID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Trip name")
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                TextField("e.g. Bonaire 2026", text: $form.title)
                    .textInputAutocapitalization(.words)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.Colors.textPrimary.opacity(0.06))
                    }
                    .accessibilityIdentifier("TripPlanner.Title")
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text(DiveTripPresentation.datesSectionTitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text(DiveTripPresentation.formattedDateRange(start: form.startDate, end: form.endDate))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                TripDateRangeCalendarView(
                    dateRange: Binding(
                        get: { (form.startDate, form.endDate) },
                        set: { range in
                            var updated = form
                            updated.startDate = range.start
                            updated.endDate = range.end
                            form = updated
                        }
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: DiveTripDateRangePickerPresentation.calendarHeight)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("TripPlanner.DateRange")

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                if !form.hasValidDateRange {
                    Text(DiveTripPresentation.invalidDateRangeMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.red)
                } else if let overlappingTrip {
                    Text(DiveTripPresentation.overlappingTripMessage(displayTitle: overlappingTrip.displayTitle))
                        .font(.footnote)
                        .foregroundStyle(Color.red)
                }

                Text(TripPlannerPresentation.newTripFormFooterHint)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Scroll surface shared by Trip Planner add / edit blue panel sheets (matches notes / buddies modals).
struct TripPlannerSheetScrollContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            content()
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, DiveActivityOverviewPanelMetrics.panelContentTopPadding)
                .padding(.bottom, AppTheme.Spacing.lg)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    TripAddSheetView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
