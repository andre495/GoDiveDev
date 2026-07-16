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
    @Environment(\.modelContext) private var modelContext

    var onConfirm: (ManualDiveEntryInput) -> Void

    @State private var diveSites: [DiveSite] = []

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
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("ManualDiveEntry.Date")
                }

                Section {
                    Picker("Dive site", selection: $siteMode) {
                        ForEach(ManualDiveEntrySiteMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
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
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("ManualDiveEntry.ChooseExistingSite")
                    case .new:
                        NavigationLink {
                            Form {
                                DiveSiteFormContent(
                                    draft: $newSiteDraft,
                                    fallbackCoordinate: nil,
                                    clearsListRowBackgrounds: true
                                )
                            }
                            .scrollContentBackground(.hidden)
                            .listStyle(.plain)
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
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("ManualDiveEntry.NewSiteDetails")
                    }
                } header: {
                    Text("Dive site")
                } footer: {
                    Text("Optional. Pick a catalog site or add a new one to link this dive when it is created.")
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: DiveActivityManualCreation.cancelAccessibilityIdentifier
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: {
                            onConfirm(
                                ManualDiveEntryInput(
                                    startTime: startTime,
                                    siteSelection: builtSiteSelection()
                                )
                            )
                            dismiss()
                        },
                        accessibilityIdentifier: DiveActivityManualCreation.doneAccessibilityIdentifier,
                        isEnabled: canConfirm
                    )
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
        .diveActivityOverviewPanelModalSheetPresentation()
        .task {
            diveSites = await DiveSiteCatalogLoader.loadSortedCatalog(modelContext: modelContext)
        }
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
