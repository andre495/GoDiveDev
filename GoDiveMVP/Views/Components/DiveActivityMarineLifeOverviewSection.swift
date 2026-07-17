import SwiftData
import SwiftUI

/// **Marine Life** overview card — unique species from media + dive-level tags (add via section header **+**).
struct DiveActivityMarineLifeOverviewSection: View {
    @Bindable var activity: DiveActivity
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @State private var catalogByUUID: [String: MarineLife] = [:]

    private var chips: [DiveActivityMarineLifeOverviewPresentation.SpeciesChip] {
        DiveActivityMarineLifeOverviewPresentation.uniqueSpeciesChips(
            sightings: activity.marineLifeSightings,
            catalog: Array(catalogByUUID.values)
        )
    }

    var body: some View {
        marineLifeContent
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("DiveOverview.MarineLifeSection")
            .task(id: activity.id) {
                await loadCatalogLookup()
            }
            .onChange(of: activity.marineLifeSightings.map(\.marineLifeUUID)) { _, _ in
                Task { await loadCatalogLookup() }
            }
    }

    @ViewBuilder
    private var marineLifeContent: some View {
        if chips.isEmpty {
            Text(DiveActivityMarineLifeOverviewPresentation.emptyValue)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Marine life, none")
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.md) {
                    ForEach(chips) { chip in
                        speciesAvatar(for: chip)
                    }
                }
                .padding(.vertical, 2)
            }
            .horizontalChipRowTrailingScrollFade()
        }
    }

    @ViewBuilder
    private func speciesAvatar(for chip: DiveActivityMarineLifeOverviewPresentation.SpeciesChip) -> some View {
        let view = DiveActivityMarineLifeAvatarChip(chip: chip)
        if let species = resolvedSpecies(for: chip) {
            NavigationLink {
                FieldGuideMarineLifeDetailView(
                    species: species,
                    ownerProfileID: accountSession.currentProfile?.id ?? activity.ownerProfileID,
                    onOpenDive: { _ in }
                )
                .hidesBottomTabBarWhenPushed()
            } label: {
                view
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .accessibilityHint("Opens Field Guide")
            .accessibilityIdentifier("DiveOverview.MarineLife.\(chip.marineLifeUUID)")
        } else {
            view
                .accessibilityIdentifier("DiveOverview.MarineLife.\(chip.marineLifeUUID)")
        }
    }

    private func resolvedSpecies(
        for chip: DiveActivityMarineLifeOverviewPresentation.SpeciesChip
    ) -> MarineLife? {
        if let linked = activity.marineLifeSightings.first(where: {
            $0.marineLifeUUID == chip.marineLifeUUID
        })?.marineLife {
            return linked
        }
        return catalogByUUID[chip.marineLifeUUID]
    }

    @MainActor
    private func loadCatalogLookup() async {
        let catalog = await MarineLifeCatalogLoader.loadSortedCatalog(modelContext: modelContext)
        catalogByUUID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.uuid, $0) })
    }
}
