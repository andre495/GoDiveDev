import SwiftData
import SwiftUI

/// Sheet form to create a new **`DiveTrip`** for the signed-in profile.
struct TripAddSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @Query private var ownerTrips: [DiveTrip]
    @Query private var ownedBuddies: [DiveBuddy]

    var onSaved: () -> Void = {}

    @State private var form = DiveTripFormValues()
    @State private var selectedBuddyIDs: Set<UUID> = []
    @State private var showsBuddyPicker = false
    @State private var showsCountryPicker = false
    @State private var saveErrorMessage: String?
    @FocusState private var isTitleFocused: Bool

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
        _ownedBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
        )
    }

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var canSaveTrip: Bool {
        form.canSave(existingOwnerTrips: ownerTrips)
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
                    isTitleFocused: $isTitleFocused,
                    addCountriesAccessibilityIdentifier: TripPlannerPresentation.addTripCountriesAccessibilityIdentifier,
                    addBuddiesAccessibilityIdentifier: TripPlannerPresentation.addTripBuddiesAccessibilityIdentifier,
                    onAddCountries: {
                        isTitleFocused = false
                        showsCountryPicker = true
                    },
                    onAddBuddies: {
                        isTitleFocused = false
                        showsBuddyPicker = true
                    }
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
        .sheet(isPresented: $showsCountryPicker) {
            TripCountryPickerSheet(selectedCountries: $form.selectedCountries)
        }
        .sheet(isPresented: $showsBuddyPicker) {
            TripPlannedBuddyPickerSheet(
                selectedBuddyIDs: $selectedBuddyIDs,
                ownerProfileID: accountSession.currentProfile?.id
            )
        }
        .accessibilityIdentifier("TripAddSheet.Root")
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private func saveTrip() {
        isTitleFocused = false
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

        DiveTripPlannedBuddyDraftPresentation.apply(
            draftBuddyIDs: selectedBuddyIDs,
            to: trip,
            rosterByID: rosterByID,
            modelContext: modelContext
        )

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
}

// MARK: - Form

struct TripPlannerFormContent: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var form: DiveTripFormValues
    @Binding var selectedBuddyIDs: Set<UUID>
    var ownedBuddies: [DiveBuddy] = []
    var existingOwnerTrips: [DiveTrip] = []
    var editingTripID: UUID? = nil
    var isTitleFocused: FocusState<Bool>.Binding
    var addCountriesAccessibilityIdentifier: String
    var addBuddiesAccessibilityIdentifier: String
    var onAddCountries: () -> Void
    var onAddBuddies: () -> Void

    @State private var isStartPickerExpanded = false
    @State private var isEndPickerExpanded = false

    private var overlappingTrip: DiveTrip? {
        form.overlappingTrip(among: existingOwnerTrips, excludingTripID: editingTripID)
    }

    private var selectedBuddies: [DiveBuddy] {
        DiveTripPlannedBuddyDraftPresentation.selectedBuddies(
            ownedBuddies: ownedBuddies,
            selectedBuddyIDs: selectedBuddyIDs,
            modelContext: modelContext
        )
    }

    private var selectedCountryRows: [DiveSiteSelectableCountry] {
        form.parsedCountries.map { name in
            let code = DiveSiteCountryPresentation.isoRegionCode(forCountryName: name) ?? ""
            return DiveSiteSelectableCountry(
                name: name,
                isoRegionCode: code,
                flagEmoji: DiveSiteCountryPresentation.flagEmoji(forCountryName: name)
            )
        }
    }

    private var showsEndDateControls: Bool {
        DiveTripDateRangePickerPresentation.shouldShowEndDateControls(
            hasChosenStartDate: form.hasChosenStartDate
        )
    }

    var body: some View {
        Section {
            TextField(TripPlannerPresentation.tripNameFieldPlaceholder, text: $form.title)
                .textInputAutocapitalization(.words)
                .focused(isTitleFocused)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("TripPlanner.Title")
        } header: {
            Text(TripPlannerPresentation.tripNameSectionTitle)
        }

        Section {
            if selectedCountryRows.isEmpty {
                Text(TripPlannerPresentation.countriesEmptySelectionMessage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("TripPlanner.Countries.Empty")
            } else {
                ForEach(selectedCountryRows) { country in
                    TripPlannerSelectedCountryRow(country: country)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("TripPlanner.Countries.Row.\(country.isoRegionCode.isEmpty ? country.name : country.isoRegionCode)")
                }
            }

        } header: {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                Text(DiveTripPresentation.countriesSectionTitle)

                Spacer(minLength: AppTheme.Spacing.sm)

                DiveActivitySectionHeaderActionButton(
                    systemImage: "plus",
                    accessibilityLabel: TripPlannerPresentation.addCountriesAccessibilityLabel,
                    action: onAddCountries
                )
                .accessibilityIdentifier(addCountriesAccessibilityIdentifier)
            }
            .textCase(nil)
        }

        Section {
            TripPlannerDateFieldRow(
                title: DiveTripDateRangePickerPresentation.startDatePickerTitle,
                valueText: form.hasChosenStartDate
                    ? DiveTripDateRangePickerPresentation.formattedFieldDate(form.startDate)
                    : DiveTripDateRangePickerPresentation.startDateFieldPlaceholder,
                isPlaceholder: !form.hasChosenStartDate,
                accessibilityIdentifier: DiveTripDateRangePickerPresentation.startDateFieldAccessibilityIdentifier
            ) {
                isTitleFocused.wrappedValue = false
                isStartPickerExpanded.toggle()
                if isStartPickerExpanded {
                    isEndPickerExpanded = false
                }
            }

            if isStartPickerExpanded {
                TripSingleDateCalendarView(
                    selectedDate: $form.startDate,
                    visibleMonthAnchor: form.startDate,
                    onDateSelected: { date in
                        var updated = form
                        updated.setStartDate(date)
                        form = updated
                        isStartPickerExpanded = false
                        isEndPickerExpanded = true
                    }
                )
                .tripPlannerSingleCalendarChrome()
                .accessibilityIdentifier(DiveTripDateRangePickerPresentation.startDateAccessibilityIdentifier)
            }

            if showsEndDateControls {
                TripPlannerDateFieldRow(
                    title: DiveTripDateRangePickerPresentation.endDatePickerTitle,
                    valueText: DiveTripDateRangePickerPresentation.formattedFieldDate(form.endDate),
                    isPlaceholder: false,
                    accessibilityIdentifier: DiveTripDateRangePickerPresentation.endDateFieldAccessibilityIdentifier
                ) {
                    isTitleFocused.wrappedValue = false
                    isEndPickerExpanded.toggle()
                    if isEndPickerExpanded {
                        isStartPickerExpanded = false
                    }
                }

                if isEndPickerExpanded {
                    TripSingleDateCalendarView(
                        selectedDate: $form.endDate,
                        visibleMonthAnchor: form.startDate,
                        onDateSelected: { date in
                            var updated = form
                            updated.setEndDate(date)
                            form = updated
                            isEndPickerExpanded = false
                        }
                    )
                    .tripPlannerSingleCalendarChrome()
                    .accessibilityIdentifier(DiveTripDateRangePickerPresentation.endDateAccessibilityIdentifier)
                }
            }

            if form.hasChosenStartDate, !form.hasValidDateRange {
                Text(DiveTripPresentation.invalidDateRangeMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
                    .listRowBackground(Color.clear)
            } else if form.hasChosenStartDate, let overlappingTrip {
                Text(DiveTripPresentation.overlappingTripMessage(displayTitle: overlappingTrip.displayTitle))
                    .font(.footnote)
                    .foregroundStyle(Color.red)
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text(DiveTripPresentation.datesSectionTitle)
        } footer: {
            Text(TripPlannerPresentation.newTripFormFooterHint)
        }

        Section {
            if selectedBuddies.isEmpty {
                Text(TripPlannerPresentation.buddiesEmptySelectionMessage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("TripPlanner.Buddies.Empty")
            } else {
                ForEach(selectedBuddies, id: \.id) { buddy in
                    TripPlannerSelectedBuddyRow(buddy: buddy)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("TripPlanner.Buddies.Row.\(buddy.id.uuidString)")
                }
            }
        } header: {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                Text(TripPlannerPresentation.buddiesSectionTitle)

                Spacer(minLength: AppTheme.Spacing.sm)

                DiveActivitySectionHeaderActionButton(
                    systemImage: "plus",
                    accessibilityLabel: TripPlannerPresentation.addBuddiesAccessibilityLabel,
                    action: onAddBuddies
                )
                .accessibilityIdentifier(addBuddiesAccessibilityIdentifier)
            }
            .textCase(nil)
        }
    }
}

private extension View {
    /// Compact **`UICalendarView`** sizing so progressive start/end calendars fit the form.
    func tripPlannerSingleCalendarChrome() -> some View {
        scaleEffect(DiveTripDateRangePickerPresentation.singleCalendarScale)
            .frame(maxWidth: .infinity)
            .frame(height: DiveTripDateRangePickerPresentation.singleCalendarHeight)
            .listRowInsets(EdgeInsets(
                top: AppTheme.Spacing.sm,
                leading: DiveTripDateRangePickerPresentation.singleCalendarHorizontalInset,
                bottom: AppTheme.Spacing.sm,
                trailing: DiveTripDateRangePickerPresentation.singleCalendarHorizontalInset
            ))
            .listRowBackground(Color.clear)
    }
}

private struct TripPlannerDateFieldRow: View {
    let title: String
    let valueText: String
    var isPlaceholder: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer(minLength: AppTheme.Spacing.sm)

                Text(valueText)
                    .font(.body)
                    .foregroundStyle(
                        isPlaceholder
                            ? AppTheme.Colors.secondaryText
                            : AppTheme.Colors.tabSelected
                    )
                    .multilineTextAlignment(.trailing)

                Image(systemName: "calendar")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityHint("Shows the calendar date picker")
    }
}

private struct TripPlannerSelectedCountryRow: View {
    let country: DiveSiteSelectableCountry

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            if let flag = country.flagEmoji, !flag.isEmpty {
                Text(flag)
                    .font(.title3)
                    .accessibilityHidden(true)
            }

            Text(country.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(country.labeledDisplayName)
    }
}

private struct TripPlannerSelectedBuddyRow: View {
    let buddy: DiveBuddy

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ProfileAvatarView(
                profilePhoto: buddy.profilePhoto,
                diameter: 36,
                iconFont: .callout,
                placeholderInitials: DiveBuddyPresentation.initials(from: buddy.displayName)
            )

            Text(buddy.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TripAddSheetView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
