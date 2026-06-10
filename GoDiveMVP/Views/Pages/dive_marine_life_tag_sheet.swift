import SwiftData
import SwiftUI

/// Overview of catalog species tagged on one dive media item.
struct DiveMarineLifeMediaTagsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem

    @Query(sort: \MarineLife.commonName) private var catalog: [MarineLife]

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
                    Button {
                        showsTagPicker = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.tabSelected)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tag marine life")
                    .accessibilityIdentifier("DiveMarineLifeMediaTags.AddTag")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if showsFishialIdentifyAction {
                        Button {
                            showsFishialIdentifySheet = true
                        } label: {
                            Image(systemName: "sparkles")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(
                                    fishialIdentifyIsActive
                                        ? AppTheme.Colors.accent
                                        : AppTheme.Colors.tabUnselected
                                )
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Identify fish")
                        .accessibilityIdentifier("DiveMarineLifeMediaTags.IdentifyFish")
                    }

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
        .onAppear(perform: reloadTaggedRows)
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

/// Catalog picker to add a species tag on dive media.
struct DiveMarineLifeTagPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(AccountSession.self) private var accountSession

    @Query(sort: \MarineLife.commonName) private var catalog: [MarineLife]

    let media: DiveMediaPhoto
    let dive: DiveActivity
    let captureContext: DiveMediaCaptureContext?
    let onTagged: () -> Void

    @State private var taggedMarineLifeUUIDs: Set<String> = []
    @State private var tagErrorMessage: String?
    @State private var speciesSearchQuery = ""
    @FocusState private var isSpeciesSearchFocused: Bool

    private var filteredCatalog: [MarineLife] {
        DiveMarineLifeTagPickerPresentation.filtering(catalog, query: speciesSearchQuery)
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
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.Colors.tabSelected)
                        .accessibilityIdentifier("DiveMarineLifeTagPicker.Done")
                }
            }
        }
        .appSheetPresentationChrome()
        .onAppear(perform: reloadTaggedMarineLifeUUIDs)
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
        if catalog.isEmpty {
            ContentUnavailableView(
                "No species in catalog",
                systemImage: "fish",
                description: Text("Field guide species will appear here when available.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredCatalog.isEmpty,
                  DiveMarineLifeTagPickerPresentation.isFiltering(query: speciesSearchQuery) {
            ContentUnavailableView.search(text: speciesSearchQuery)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            speciesList
        }
    }

    private var speciesList: some View {
        List {
            ForEach(filteredCatalog, id: \.uuid) { species in
                Button {
                    saveTag(species)
                } label: {
                    let snapshot = species.fieldGuideCatalogSnapshot
                    DiveMarineLifeTagSpeciesRow(
                        commonName: snapshot.commonName,
                        trailingLabel: FieldGuidePresentation.listTrailingLabel(category: snapshot.category),
                        detailLine: FieldGuidePresentation.listDetailLine(
                            scientificName: snapshot.scientificName,
                            sizeDepthLine: FieldGuidePresentation.sizeDepthLine(
                                for: snapshot,
                                unitSystem: diveDisplayUnitSystem
                            )
                        ),
                        featureImageURL: snapshot.featureImageURL,
                        featureImageResourceName: snapshot.featureImageResourceName,
                        showsTaggedCheckmark: taggedMarineLifeUUIDs.contains(species.uuid)
                    )
                    .equatable()
                }
                .buttonStyle(.plain)
                .disabled(taggedMarineLifeUUIDs.contains(species.uuid))
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

    private var tagErrorPresented: Binding<Bool> {
        Binding(
            get: { tagErrorMessage != nil },
            set: { if !$0 { tagErrorMessage = nil } }
        )
    }

    private func reloadTaggedMarineLifeUUIDs() {
        let sightings: [SightingInstance] = (try? MarineLifeSightingRecorder.sightings(
            forMediaPhotoID: media.id,
            modelContext: modelContext
        )) ?? []
        taggedMarineLifeUUIDs = Set(sightings.map(\.marineLifeUUID))
    }

    private func saveTag(_ species: MarineLife) {
        guard !taggedMarineLifeUUIDs.contains(species.uuid) else { return }

        guard let owner = accountSession.currentProfile else {
            tagErrorMessage = "Sign in to tag marine life."
            return
        }
        do {
            _ = try MarineLifeSightingRecorder.tagSpecies(
                species,
                on: media,
                dive: dive,
                captureContext: captureContext,
                owner: owner,
                modelContext: modelContext
            )
            taggedMarineLifeUUIDs.insert(species.uuid)
            onTagged()
        } catch {
            tagErrorMessage = error.localizedDescription
        }
    }
}
