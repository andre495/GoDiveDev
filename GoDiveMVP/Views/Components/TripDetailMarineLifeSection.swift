import SwiftUI

/// Tagged marine life on a trip — Field Guide mosaic grid (image, name, scientific name, size/depth).
struct TripDetailMarineLifeSection: View {
    let items: [TripDetailMarineLifeCarouselItem]
    let marineLifeCatalog: [MarineLife]
    let unitSystem: DiveDisplayUnitSystem
    let ownerProfileID: UUID?
    var onOpenDive: (UUID) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.md),
        GridItem(.flexible(), spacing: AppTheme.Spacing.md),
    ]

    var body: some View {
        Group {
            if items.isEmpty {
                Text(DiveTripPresentation.tripMarineLifeEmptyMessage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("TripDetail.MarineLife.Empty")
            } else {
                LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
                    ForEach(items) { item in
                        mosaicCard(for: item)
                    }
                }
                .accessibilityIdentifier("TripDetail.MarineLife.Grid")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("TripDetail.MarineLifeSection")
    }

    @ViewBuilder
    private func mosaicCard(for item: TripDetailMarineLifeCarouselItem) -> some View {
        let card = FieldGuideSpeciesMosaicCard(
            entry: item.catalogSnapshot,
            unitSystem: unitSystem,
            accent: FieldGuideCategoryAccent.gradientTop(item.categoryID),
            supplementaryLine: item.sightingCountLabel
        )
        .equatable()

        if item.hasCatalogEntry,
           let species = marineLifeCatalog.first(where: { $0.uuid == item.marineLifeUUID }) {
            NavigationLink {
                FieldGuideMarineLifeDetailView(
                    species: species,
                    ownerProfileID: ownerProfileID,
                    onOpenDive: onOpenDive
                )
                .hidesBottomTabBarWhenPushed()
            } label: {
                card
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .accessibilityIdentifier("TripDetail.MarineLife.\(item.marineLifeUUID)")
        } else {
            card
                .accessibilityIdentifier("TripDetail.MarineLife.\(item.marineLifeUUID)")
        }
    }
}
