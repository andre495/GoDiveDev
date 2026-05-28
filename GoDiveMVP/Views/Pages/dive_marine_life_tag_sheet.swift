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

    @State private var taggedRows: [MarineLifeMediaTagPresentation.TaggedSpeciesRow] = []
    @State private var showsTagPicker = false

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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Tag marine life", systemImage: "plus") {
                        showsTagPicker = true
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("DiveMarineLifeMediaTags.AddTag")
                }
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
                FieldGuideMarineLifeRow(
                    data: FieldGuidePresentation.MarineLifeRowDisplayData(
                        marineLifeUUID: row.marineLifeUUID,
                        displayName: row.commonName,
                        trailingLabel: FieldGuidePresentation.listTrailingLabel(category: row.category),
                        detailLine: FieldGuidePresentation.listDetailLine(
                            scientificName: row.scientificName,
                            sizeDepthLine: row.detailLine
                        ),
                        isSighted: true
                    )
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

    var body: some View {
        NavigationStack {
            Group {
                if catalog.isEmpty {
                    ContentUnavailableView(
                        "No species in catalog",
                        systemImage: "fish",
                        description: Text("Field guide species will appear here when available.")
                    )
                } else {
                    speciesList
                }
            }
            .appSheetContentTopSpacing()
            .navigationTitle("Tag marine life")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
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

    private var speciesList: some View {
        List {
            ForEach(catalog, id: \.uuid) { species in
                Button {
                    saveTag(species)
                } label: {
                    FieldGuideMarineLifeRow(
                        data: FieldGuidePresentation.marineLifeRowDisplayData(
                            for: species.fieldGuideCatalogSnapshot,
                            unitSystem: diveDisplayUnitSystem,
                            isSighted: taggedMarineLifeUUIDs.contains(species.uuid)
                        )
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
