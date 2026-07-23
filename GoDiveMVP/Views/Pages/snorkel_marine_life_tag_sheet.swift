import SwiftData
import SwiftUI

/// Catalog picker to add a species tag on snorkel media (blue overview-panel modal).
struct SnorkelMarineLifeTagPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(AccountSession.self) private var accountSession

    @State private var catalog: [MarineLife] = []
    @State private var hasLoadedCatalog = false

    let media: SnorkelMediaPhoto
    let snorkel: SnorkelActivity
    let onTagged: () -> Void

    @State private var catalogCache = DiveMarineLifeTagPickerPresentation.CatalogCache(
        snapshots: [],
        searchableTextByUUID: [:]
    )
    @State private var catalogByUUID: [String: MarineLife] = [:]
    @State private var allPickerRows: [DiveMarineLifeTagPickerPresentation.RowDisplayData] = []
    @State private var displayedRows: [DiveMarineLifeTagPickerPresentation.RowDisplayData] = []
    @State private var persistedMarineLifeUUIDs: Set<String> = []
    @State private var pendingMarineLifeUUIDs: Set<String> = []
    @State private var tagErrorMessage: String?
    @State private var speciesSearchQuery = ""
    @FocusState private var isSpeciesSearchFocused: Bool
    @State private var rowsRefreshTask: Task<Void, Never>?
    @State private var showsAddSpeciesSheet = false

    private var isFilteringSpecies: Bool {
        DiveMarineLifeTagPickerPresentation.isFiltering(query: speciesSearchQuery)
    }

    private var effectiveTaggedUUIDs: Set<String> {
        persistedMarineLifeUUIDs.union(pendingMarineLifeUUIDs)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                speciesSearchChrome
                pickerContent
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: discardPendingTagsAndDismiss,
                        accessibilityIdentifier: DiveMarineLifeTagPickerPresentation.cancelAccessibilityIdentifier
                    )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    AppSheetToolbarPlusButton(
                        action: { showsAddSpeciesSheet = true },
                        accessibilityIdentifier: DiveMarineLifeTagPickerPresentation.addSpeciesAccessibilityIdentifier,
                        accessibilityLabel: DiveMarineLifeTagPickerPresentation.addSpeciesAccessibilityLabel
                    )
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: confirmPendingTagsAndDismiss,
                        accessibilityIdentifier: DiveMarineLifeTagPickerPresentation.doneAccessibilityIdentifier,
                        title: DiveMarineLifeTagPickerPresentation.doneButtonTitle
                    )
                }
            }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .sheet(isPresented: $showsAddSpeciesSheet) {
            FieldGuideMarineLifeAddSheet { speciesUUID in
                Task { @MainActor in
                    await incorporateNewlyAddedSpecies(uuid: speciesUUID)
                }
            }
        }
        .task(id: media.id) {
            await loadCatalogIfNeeded()
            reloadTaggedMarineLifeUUIDs()
            syncCatalogCache()
            refreshDisplayedRows(immediate: true)
        }
        .onChange(of: catalog.count) { _, _ in
            syncCatalogCache()
            refreshDisplayedRows(immediate: true)
        }
        .onChange(of: speciesSearchQuery) { _, _ in
            refreshDisplayedRows()
        }
        .onDisappear {
            rowsRefreshTask?.cancel()
            rowsRefreshTask = nil
        }
        .alert("Could not save tag", isPresented: tagErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(tagErrorMessage ?? "Try again.")
        }
        .accessibilityIdentifier("SnorkelMarineLifeTagPicker.Root")
    }

    private var speciesSearchChrome: some View {
        CatalogListSearchChrome(
            searchText: $speciesSearchQuery,
            isSearchFocused: $isSpeciesSearchFocused,
            placeholder: DiveMarineLifeTagPickerPresentation.searchPlaceholder,
            searchFieldAccessibilityIdentifier: "SnorkelMarineLifeTagPicker.SearchField",
            cancelAccessibilityIdentifier: "SnorkelMarineLifeTagPicker.SearchCancel",
            showsTrailingActions: false,
            trailingActions: { EmptyView() }
        )
    }

    @ViewBuilder
    private var pickerContent: some View {
        if !hasLoadedCatalog, catalog.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if catalog.isEmpty {
            ContentUnavailableView(
                "No species in catalog",
                systemImage: "fish",
                description: Text("Tap + to add a species, or wait for the Field Guide catalog to load.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if displayedRows.isEmpty, isFilteringSpecies {
            ContentUnavailableView.search(text: speciesSearchQuery)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            speciesList
        }
    }

    private var speciesList: some View {
        List {
            ForEach(displayedRows) { row in
                Button {
                    stageTag(for: row)
                } label: {
                    DiveMarineLifeTagSpeciesRow(
                        commonName: row.commonName,
                        trailingLabel: row.trailingLabel,
                        detailLine: row.detailLine,
                        featureImageURL: row.featureImageURL,
                        featureImageResourceName: row.featureImageResourceName,
                        showsTaggedCheckmark: row.isTagged
                    )
                    .equatable()
                }
                .buttonStyle(.plain)
                .disabled(row.isTagged)
                .listRowInsets(EdgeInsets(
                    top: AppTheme.Spacing.sm,
                    leading: AppTheme.Spacing.lg,
                    bottom: AppTheme.Spacing.sm,
                    trailing: AppTheme.Spacing.lg
                ))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(nil, value: displayedRows.count)
    }

    private var tagErrorPresented: Binding<Bool> {
        Binding(
            get: { tagErrorMessage != nil },
            set: { if !$0 { tagErrorMessage = nil } }
        )
    }

    private func loadCatalogIfNeeded() async {
        guard catalog.isEmpty else {
            hasLoadedCatalog = true
            return
        }
        catalog = await MarineLifeCatalogLoader.loadSortedCatalog(modelContext: modelContext)
        hasLoadedCatalog = true
    }

    @MainActor
    private func incorporateNewlyAddedSpecies(uuid: String) async {
        catalog = await MarineLifeCatalogLoader.loadSortedCatalog(modelContext: modelContext)
        hasLoadedCatalog = true
        syncCatalogCache()
        pendingMarineLifeUUIDs.insert(uuid)
        rebuildAllPickerRows()
        markRowTagged(marineLifeUUID: uuid, isTagged: true)
        refreshDisplayedRows(immediate: true)
    }

    private func syncCatalogCache() {
        let nextCache = DiveMarineLifeTagPickerPresentation.CatalogCache.make(from: catalog)
        guard nextCache != catalogCache else {
            catalogByUUID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.uuid, $0) })
            return
        }
        catalogCache = nextCache
        catalogByUUID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.uuid, $0) })
        rebuildAllPickerRows()
    }

    private func rebuildAllPickerRows() {
        allPickerRows = DiveMarineLifeTagPickerPresentation.makePickerRows(
            snapshots: catalogCache.snapshots,
            taggedUUIDs: effectiveTaggedUUIDs,
            unitSystem: diveDisplayUnitSystem
        )
    }

    private func refreshDisplayedRows(immediate: Bool = false) {
        rowsRefreshTask?.cancel()
        let query = speciesSearchQuery
        let rows = allPickerRows
        let snapshots = catalogCache.snapshots
        let searchableTextByUUID = catalogCache.searchableTextByUUID
        let debounceNanoseconds = immediate
            ? UInt64(0)
            : DiveMarineLifeTagPickerPresentation.searchDebounceNanoseconds

        rowsRefreshTask = Task {
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled else { return }

            let filteredRows = await Task.detached {
                DiveMarineLifeTagPickerPresentation.filteredPickerRows(
                    allRows: rows,
                    snapshots: snapshots,
                    searchableTextByUUID: searchableTextByUUID,
                    query: query
                )
            }.value

            guard !Task.isCancelled else { return }
            displayedRows = filteredRows
        }
    }

    private func reloadTaggedMarineLifeUUIDs() {
        let sightings: [SightingInstance] = (try? MarineLifeSightingRecorder.sightings(
            forMediaPhotoID: media.id,
            modelContext: modelContext
        )) ?? []
        persistedMarineLifeUUIDs = Set(sightings.map(\.marineLifeUUID))
        pendingMarineLifeUUIDs.removeAll()
    }

    private func stageTag(for row: DiveMarineLifeTagPickerPresentation.RowDisplayData) {
        guard !effectiveTaggedUUIDs.contains(row.marineLifeUUID) else { return }
        pendingMarineLifeUUIDs.insert(row.marineLifeUUID)
        markRowTagged(marineLifeUUID: row.marineLifeUUID, isTagged: true)
    }

    private func discardPendingTagsAndDismiss() {
        pendingMarineLifeUUIDs.removeAll()
        dismiss()
    }

    private func confirmPendingTagsAndDismiss() {
        if commitPendingTags() {
            dismiss()
        }
    }

    private func markRowTagged(marineLifeUUID: String, isTagged: Bool) {
        if let index = allPickerRows.firstIndex(where: { $0.marineLifeUUID == marineLifeUUID }) {
            allPickerRows[index] = DiveMarineLifeTagPickerPresentation.rowMarkedTagged(
                allPickerRows[index],
                isTagged: isTagged
            )
        }
        if let index = displayedRows.firstIndex(where: { $0.marineLifeUUID == marineLifeUUID }) {
            displayedRows[index] = DiveMarineLifeTagPickerPresentation.rowMarkedTagged(
                displayedRows[index],
                isTagged: isTagged
            )
        }
    }

    @discardableResult
    private func commitPendingTags() -> Bool {
        guard !pendingMarineLifeUUIDs.isEmpty else { return true }

        let speciesToPersist = pendingMarineLifeUUIDs.compactMap { catalogByUUID[$0] }
        guard speciesToPersist.count == pendingMarineLifeUUIDs.count else {
            tagErrorMessage = "Could not find one or more species in the catalog."
            return false
        }

        guard let owner = accountSession.currentProfile else {
            tagErrorMessage = "Sign in to tag marine life."
            return false
        }

        do {
            try MarineLifeSightingRecorder.tagPendingSpecies(
                speciesToPersist,
                on: media,
                snorkel: snorkel,
                owner: owner,
                modelContext: modelContext
            )
            persistedMarineLifeUUIDs.formUnion(pendingMarineLifeUUIDs)
            pendingMarineLifeUUIDs.removeAll()
            onTagged()
            return true
        } catch {
            tagErrorMessage = error.localizedDescription
            return false
        }
    }
}
