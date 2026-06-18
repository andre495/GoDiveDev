import SwiftData
import SwiftUI

private enum ManualDiveEntrySiteMode: String, CaseIterable, Identifiable {
    case none
    case existing
    case new

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .existing: "Existing"
        case .new: "New site"
        }
    }
}

/// Confirms date and optional catalog dive site before **`DiveActivityManualCreation`** inserts a manual dive.
struct ManualDiveEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DiveSite.siteName) private var diveSites: [DiveSite]

    var onConfirm: (ManualDiveEntryInput) -> Void

    @State private var startTime = Date()
    @State private var siteMode: ManualDiveEntrySiteMode = .none
    @State private var selectedExistingSiteID: UUID?
    @State private var newSiteDraft = DiveSiteFormDraft(
        siteName: "",
        country: "",
        region: "",
        bodyOfWater: "",
        latitudeText: "",
        longitudeText: ""
    )
    @State private var showsSitePicker = false

    private var selectedExistingSite: DiveSite? {
        guard let selectedExistingSiteID else { return nil }
        return diveSites.first { $0.id == selectedExistingSiteID }
    }

    private var canConfirm: Bool {
        switch siteMode {
        case .none:
            return true
        case .existing:
            return selectedExistingSiteID != nil
        case .new:
            return DiveSiteFormValidation.canSave(draft: newSiteDraft)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Date",
                        selection: $startTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityIdentifier("ManualDiveEntry.Date")
                }

                Section {
                    Picker("Dive site", selection: $siteMode) {
                        ForEach(ManualDiveEntrySiteMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("ManualDiveEntry.SiteMode")

                    switch siteMode {
                    case .none:
                        EmptyView()
                    case .existing:
                        Button {
                            showsSitePicker = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selectedExistingSite?.siteName ?? "Choose a site")
                                        .foregroundStyle(
                                            selectedExistingSite == nil
                                                ? AppTheme.Colors.secondaryText
                                                : AppTheme.Colors.textPrimary
                                        )
                                    if let placeLine = selectedExistingSite.map({
                                        ExploreDiveSiteListDisplay.cityCountryLine(
                                            country: $0.country,
                                            region: $0.region
                                        )
                                    }), !placeLine.isEmpty {
                                        Text(placeLine)
                                            .font(.footnote)
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                    }
                                }
                                Spacer(minLength: AppTheme.Spacing.sm)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                        }
                        .accessibilityIdentifier("ManualDiveEntry.ChooseExistingSite")
                    case .new:
                        NavigationLink {
                            Form {
                                DiveSiteFormContent(
                                    draft: $newSiteDraft,
                                    fallbackCoordinate: nil
                                )
                            }
                            .scrollContentBackground(.hidden)
                            .navigationTitle("New dive site")
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(newSiteSummaryTitle)
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                    if let subtitle = newSiteSummarySubtitle {
                                        Text(subtitle)
                                            .font(.footnote)
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                    }
                                }
                                Spacer(minLength: AppTheme.Spacing.sm)
                            }
                        }
                        .accessibilityIdentifier("ManualDiveEntry.NewSiteDetails")
                    }
                } header: {
                    Text("Dive site")
                } footer: {
                    Text("Optional. Pick a catalog site or add a new one to link this dive when it is created.")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("New dive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("ManualDiveEntry.Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onConfirm(
                            ManualDiveEntryInput(
                                startTime: startTime,
                                siteSelection: builtSiteSelection()
                            )
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canConfirm)
                    .accessibilityIdentifier("ManualDiveEntry.Confirm")
                }
            }
            .sheet(isPresented: $showsSitePicker) {
                ManualDiveEntrySitePickerSheet(
                    selectedSiteID: $selectedExistingSiteID,
                    sites: diveSites
                )
            }
            .onChange(of: siteMode) { _, newMode in
                switch newMode {
                case .none:
                    selectedExistingSiteID = nil
                case .existing:
                    newSiteDraft = emptyNewSiteDraft()
                case .new:
                    selectedExistingSiteID = nil
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .appSheetPresentationChrome()
        .accessibilityIdentifier("ManualDiveEntry.Sheet")
    }

    private var newSiteSummaryTitle: String {
        DiveSiteFormValidation.sanitizedSiteName(newSiteDraft.siteName) ?? "Add site details"
    }

    private var newSiteSummarySubtitle: String? {
        let place = ExploreDiveSiteListDisplay.cityCountryLine(
            country: newSiteDraft.country,
            region: newSiteDraft.region
        )
        if !place.isEmpty { return place }
        return newSiteDraft.waterType.displayTitle
    }

    private func builtSiteSelection() -> ManualDiveEntrySiteSelection {
        switch siteMode {
        case .none:
            return .none
        case .existing:
            guard let selectedExistingSiteID else { return .none }
            return .existingSite(id: selectedExistingSiteID)
        case .new:
            return .newSite(newSiteDraft)
        }
    }

    private func emptyNewSiteDraft() -> DiveSiteFormDraft {
        DiveSiteFormDraft(
            siteName: "",
            country: "",
            region: "",
            bodyOfWater: "",
            latitudeText: "",
            longitudeText: ""
        )
    }
}
