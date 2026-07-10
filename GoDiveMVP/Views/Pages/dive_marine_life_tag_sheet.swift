import SwiftData
import SwiftUI

/// Overview of catalog species tagged on one dive media item.
struct DiveMarineLifeMediaTagsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem

    @State private var catalog: [MarineLife] = []
    @State private var hasLoadedCatalog = false

    let media: DiveMediaPhoto
    let dive: DiveActivity
    let captureContext: DiveMediaCaptureContext?
    var catalogSites: [DiveSite] = []

    @State private var taggedRows: [MarineLifeMediaTagPresentation.TaggedSpeciesRow] = []
    @State private var showsTagPicker = false
    @State private var showsFishialIdentifySheet = false

    private var showsFishialIdentifyAction: Bool {
        DiveMarineLifeTagSheetPresentation.showsFishialIdentifyAction
    }

    private var fishialIdentifyIsActive: Bool {
        DiveMarineLifeTagSheetPresentation.fishialIdentifyIsActive(
            confirmedSpeciesName: media.resolvedFishialConfirmedSpeciesName
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if taggedRows.isEmpty {
                    ContentUnavailableView(
                        "No species tagged",
                        systemImage: "fish",
                        description: Text("Tag marine life you spotted in this photo.")
                    )
                } else {
                    taggedSpeciesList
                }
            }
            .appSheetContentTopSpacing()
            .navigationTitle("Marine life")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DiveMarineLifeTagSheetLeadingToolbar(
                        showsFishialIdentifyAction: showsFishialIdentifyAction,
                        fishialIdentifyIsActive: fishialIdentifyIsActive,
                        onAddTag: { showsTagPicker = true },
                        onIdentifyFish: { showsFishialIdentifySheet = true }
                    )
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.Colors.tabSelected)
                        .accessibilityIdentifier("DiveMarineLifeMediaTags.Done")
                }
            }
            .sheet(isPresented: $showsFishialIdentifySheet, onDismiss: reloadTaggedRows) {
                DiveMediaFishialIdentifySheet(
                    media: media,
                    dive: dive,
                    catalogSites: catalogSites,
                    captureContext: captureContext
                )
            }
            .sheet(isPresented: $showsTagPicker) {
                DiveMarineLifeTagPickerSheet(
                    media: media,
                    dive: dive,
                    captureContext: captureContext,
                    onTagged: reloadTaggedRows
                )
            }
        }
        .appSheetPresentationChrome()
        .task(id: media.id) {
            await loadCatalogIfNeeded()
            reloadTaggedRows()
        }
        .onChange(of: catalog.count) { _, _ in
            reloadTaggedRows()
        }
    }

    private var taggedSpeciesList: some View {
        List {
            ForEach(taggedRows) { row in
                DiveMarineLifeTagSpeciesRow(
                    commonName: row.commonName,
                    trailingLabel: FieldGuidePresentation.listTrailingLabel(category: row.category),
                    detailLine: FieldGuidePresentation.listDetailLine(
                        scientificName: row.scientificName,
                        sizeDepthLine: row.detailLine
                    ),
                    featureImageURL: row.featureImageURL,
                    featureImageResourceName: row.featureImageResourceName
                )
                .equatable()
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
    }

    private func loadCatalogIfNeeded() async {
        guard catalog.isEmpty else {
            hasLoadedCatalog = true
            return
        }
        catalog = await MarineLifeCatalogLoader.loadSortedCatalog(modelContext: modelContext)
        hasLoadedCatalog = true
    }

    private func reloadTaggedRows() {
        let sightings: [SightingInstance] = (try? MarineLifeSightingRecorder.sightings(
            forMediaPhotoID: media.id,
            modelContext: modelContext
        )) ?? []
        taggedRows = MarineLifeMediaTagPresentation.taggedRows(
            mediaPhotoID: media.id,
            sightings: sightings,
            catalog: catalog,
            unitSystem: diveDisplayUnitSystem
        )
    }
}

// MARK: - Leading toolbar (+ tag + Fishial AI)

private struct DiveMarineLifeTagSheetLeadingToolbar: View {
    let showsFishialIdentifyAction: Bool
    let fishialIdentifyIsActive: Bool
    let onAddTag: () -> Void
    let onIdentifyFish: () -> Void

    var body: some View {
        HStack(spacing: DiveMarineLifeTagSheetPresentation.leadingToolbarSpacing) {
            Button(action: onAddTag) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tag marine life")
            .accessibilityIdentifier("DiveMarineLifeMediaTags.AddTag")

            if showsFishialIdentifyAction {
                Button(action: onIdentifyFish) {
                    Image(systemName: "sparkles")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DiveMarineLifeTagSheetPresentation.fishialIdentifyIconGradient)
                        .opacity(fishialIdentifyIsActive ? 1 : 0.92)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Identify fish with AI")
                .accessibilityIdentifier("DiveMarineLifeMediaTags.IdentifyFish")
            }
        }
    }
}

/// Catalog picker to add a species tag on dive media.
struct DiveMarineLifeTagPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(AccountSession.self) private var accountSession

    @State private var catalog: [MarineLife] = []
    @State private var hasLoadedCatalog = false

    let media: DiveMediaPhoto
    let dive: DiveActivity
    let captureContext: DiveMediaCaptureContext?
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
            .appSheetContentTopSpacing()
            .navigationTitle("Tag marine life")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if commitPendingTags() {
                            dismiss()
                        }
                    }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.Colors.tabSelected)
                        .accessibilityIdentifier("DiveMarineLifeTagPicker.Done")
                }
            }
        }
        .appSheetPresentationChrome()
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
    }

    private var speciesSearchChrome: some View {
        CatalogListSearchChrome(
            searchText: $speciesSearchQuery,
            isSearchFocused: $isSpeciesSearchFocused,
            placeholder: DiveMarineLifeTagPickerPresentation.searchPlaceholder,
            searchFieldAccessibilityIdentifier: "DiveMarineLifeTagPicker.SearchField",
            cancelAccessibilityIdentifier: "DiveMarineLifeTagPicker.SearchCancel",
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
                description: Text("Field guide species will appear here when available.")
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

    private func syncCatalogCache() {
        let nextCache = DiveMarineLifeTagPickerPresentation.CatalogCache.make(from: catalog)
        guard nextCache != catalogCache else { return }
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
                dive: dive,
                captureContext: captureContext,
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
