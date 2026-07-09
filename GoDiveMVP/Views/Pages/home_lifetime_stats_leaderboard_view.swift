import SwiftData
import SwiftUI

/// Ranked top-ten list for a Home lifetime stat tile (deepest, longest, sites, species).
struct HomeLifetimeStatsLeaderboardView: View {
    let kind: HomeLifetimeStatsLeaderboardKind
    let diveStatsInputs: [HomeDiveStatsInput]
    let activities: [DiveActivity]
    let diveSites: [DiveSite]
    let marineLifeCatalog: [MarineLife]
    let unitSystem: DiveDisplayUnitSystem
    let automaticallyRenumberDives: Bool
    let sightings: [HomeLifetimeStatsPresentation.SightingCountInput]
    let onOpenDive: (UUID) -> Void
    let onOpenSite: (UUID) -> Void
    let onOpenSpecies: (String) -> Void

    private var diveStatsByID: [UUID: HomeDiveStatsInput] {
        Dictionary(uniqueKeysWithValues: diveStatsInputs.map { ($0.id, $0) })
    }

    private var diveRows: [DiveLogbookRowDisplayData] {
        let rankedIDs = HomeLifetimeStatsLeaderboardPresentation.rankedDiveIDs(
            dives: diveStatsInputs,
            kind: kind
        )
        let activitiesByID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
        let rankedActivities = rankedIDs.compactMap { activitiesByID[$0] }
        return DiveLogbookDisplay.rowData(
            activities: rankedActivities,
            unitSystem: unitSystem,
            duplicateIds: [],
            useChronologicalNumbers: automaticallyRenumberDives,
            numberingActivities: activities
        )
    }

    private var siteEntries: [HomeLifetimeStatsLeaderboardPresentation.SiteEntry] {
        HomeLifetimeStatsLeaderboardPresentation.topSites(dives: diveStatsInputs)
    }

    private var speciesEntries: [HomeLifetimeStatsLeaderboardPresentation.SpeciesEntry] {
        HomeLifetimeStatsLeaderboardPresentation.topSpecies(sightings: sightings)
    }

    private var sitesByID: [UUID: DiveSite] {
        Dictionary(uniqueKeysWithValues: diveSites.map { ($0.id, $0) })
    }

    private var marineLifeByUUID: [String: MarineLife] {
        Dictionary(uniqueKeysWithValues: marineLifeCatalog.map { ($0.uuid, $0) })
    }

    private var speciesRowData: [HomeLifetimeStatsLeaderboardPresentation.SpeciesRowDisplayData] {
        speciesEntries.map { entry in
            let catalogSpecies = marineLifeByUUID[entry.marineLifeUUID]
            return HomeLifetimeStatsLeaderboardPresentation.speciesRowDisplayData(
                entry: entry,
                featureImageURL: catalogSpecies?.featureImageURL ?? "",
                featureImageResourceName: catalogSpecies?.featureImageResourceName ?? ""
            )
        }
    }

    private var showsEmptyState: Bool {
        switch kind {
        case .deepestDives, .longestDives:
            return diveRows.isEmpty
        case .topSites:
            return siteEntries.isEmpty
        case .topSpecies:
            return speciesEntries.isEmpty
        }
    }

    var body: some View {
        AppPage(
            title: HomeLifetimeStatsLeaderboardPresentation.pageTitle(for: kind),
            showsBackButton: true,
            showsBrandWordmark: false,
            titlePlacement: AppHeaderStackedTitleChrome.titlePlacement,
            scrollContentUnderHeader: true,
            showsWaterBubbleBackground: !GoDiveUITestConfiguration.isActive,
            trailingContent: { EmptyView() },
            content: {
                if showsEmptyState {
                    AppScrollUnderHeaderEmptyState {
                        emptyState
                    }
                } else {
                    AppScrollUnderHeaderList(
                        listAccessibilityIdentifier: listAccessibilityIdentifier
                    ) {
                        listRows
                    }
                }
            }
        )
        .hidesBottomTabBarWhenPushed()
        .accessibilityIdentifier(accessibilityRootIdentifier)
    }

    @ViewBuilder
    private var listRows: some View {
        podiumSection
            .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

        switch kind {
        case .deepestDives, .longestDives:
            ForEach(Array(listPortionDiveRows.enumerated()), id: \.element.id) { index, row in
                let rank = HomeLifetimeStatsLeaderboardPresentation.podiumLimit + index + 1
                Button {
                    onOpenDive(row.id)
                } label: {
                    HomeLifetimeStatsLeaderboardRankedRow(rank: rank) {
                        LogbookActivityRow(data: row)
                            .equatable()
                    }
                }
                .buttonStyle(.plain)
                .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("\(accessibilityRootIdentifier).Row.\(row.id.uuidString)")
            }
        case .topSites:
            ForEach(listPortionSiteEntries) { entry in
                let rowData = HomeLifetimeStatsLeaderboardPresentation.siteRowDisplayData(
                    entry: entry,
                    site: entry.siteID.flatMap { sitesByID[$0] }
                )
                Group {
                    if let siteID = entry.siteID {
                        Button {
                            onOpenSite(siteID)
                        } label: {
                            HomeLifetimeStatsLeaderboardRankedRow(rank: entry.rank) {
                                ExploreDiveSiteRow(data: rowData)
                                    .equatable()
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        HomeLifetimeStatsLeaderboardRankedRow(rank: entry.rank) {
                            ExploreDiveSiteRow(data: rowData)
                                .equatable()
                        }
                    }
                }
                .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("\(accessibilityRootIdentifier).Row.\(entry.rank)")
            }
        case .topSpecies:
            ForEach(listPortionSpeciesRowData) { row in
                Button {
                    onOpenSpecies(row.marineLifeUUID)
                } label: {
                    HomeLifetimeStatsLeaderboardRankedRow(rank: speciesRank(for: row)) {
                        HomeLifetimeStatsLeaderboardSpeciesRow(data: row)
                            .equatable()
                    }
                }
                .buttonStyle(.plain)
                .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("\(accessibilityRootIdentifier).Row.\(row.id)")
            }
        }
    }

    private var podiumSection: some View {
        HomeLifetimeStatsLeaderboardPodiumSection(
            kind: kind,
            unitSystem: unitSystem,
            diveStatsByID: diveStatsByID,
            diveRows: podiumDiveRows,
            siteEntries: podiumSiteEntries,
            speciesEntries: podiumSpeciesEntries,
            speciesRowData: podiumSpeciesRowData,
            accessibilityRootIdentifier: accessibilityRootIdentifier,
            onOpenDive: onOpenDive,
            onOpenSite: onOpenSite,
            onOpenSpecies: onOpenSpecies
        )
    }

    private var podiumDiveRows: [DiveLogbookRowDisplayData] {
        Array(diveRows.prefix(HomeLifetimeStatsLeaderboardPresentation.podiumLimit))
    }

    private var listPortionDiveRows: [DiveLogbookRowDisplayData] {
        Array(diveRows.dropFirst(HomeLifetimeStatsLeaderboardPresentation.podiumLimit))
    }

    private var podiumSiteEntries: [HomeLifetimeStatsLeaderboardPresentation.SiteEntry] {
        Array(siteEntries.prefix(HomeLifetimeStatsLeaderboardPresentation.podiumLimit))
    }

    private var listPortionSiteEntries: [HomeLifetimeStatsLeaderboardPresentation.SiteEntry] {
        Array(siteEntries.dropFirst(HomeLifetimeStatsLeaderboardPresentation.podiumLimit))
    }

    private var podiumSpeciesEntries: [HomeLifetimeStatsLeaderboardPresentation.SpeciesEntry] {
        Array(speciesEntries.prefix(HomeLifetimeStatsLeaderboardPresentation.podiumLimit))
    }

    private var podiumSpeciesRowData: [HomeLifetimeStatsLeaderboardPresentation.SpeciesRowDisplayData] {
        Array(speciesRowData.prefix(HomeLifetimeStatsLeaderboardPresentation.podiumLimit))
    }

    private var listPortionSpeciesRowData: [HomeLifetimeStatsLeaderboardPresentation.SpeciesRowDisplayData] {
        Array(speciesRowData.dropFirst(HomeLifetimeStatsLeaderboardPresentation.podiumLimit))
    }

    private func speciesRank(for row: HomeLifetimeStatsLeaderboardPresentation.SpeciesRowDisplayData) -> Int {
        speciesEntries.first(where: { $0.marineLifeUUID == row.marineLifeUUID })?.rank ?? 0
    }

    private var emptyState: some View {
        AppComingSoonPlaceholder(
            systemImage: emptyStateSymbol,
            message: emptyStateMessage
        )
        .padding(.top, AppTheme.Spacing.lg)
    }

    private var emptyStateSymbol: String {
        switch kind {
        case .deepestDives, .longestDives:
            return "water.waves"
        case .topSites:
            return "mappin.circle"
        case .topSpecies:
            return "fish"
        }
    }

    private var emptyStateMessage: String {
        switch kind {
        case .deepestDives, .longestDives:
            return "Log dives to see your deepest and longest highlights here."
        case .topSites:
            return "Link dive sites on your dives to build a visit leaderboard."
        case .topSpecies:
            return "Tag marine life on your dives to see your most sighted species."
        }
    }

    private var accessibilityRootIdentifier: String {
        switch kind {
        case .deepestDives:
            return "Home.LifetimeStatsLeaderboard.Deepest"
        case .longestDives:
            return "Home.LifetimeStatsLeaderboard.Longest"
        case .topSites:
            return "Home.LifetimeStatsLeaderboard.TopSites"
        case .topSpecies:
            return "Home.LifetimeStatsLeaderboard.TopSpecies"
        }
    }

    private var listAccessibilityIdentifier: String {
        "\(accessibilityRootIdentifier).List"
    }
}

private struct HomeLifetimeStatsLeaderboardRankedRow<Content: View>: View {
    let rank: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            HomeLifetimeStatsLeaderboardRankBadge(rank: rank)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HomeLifetimeStatsLeaderboardSpeciesRow: View, Equatable {
    let data: HomeLifetimeStatsLeaderboardPresentation.SpeciesRowDisplayData

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            if data.showsPreviewImage {
                FieldGuideMarineLifeCatalogImage(
                    imageURLString: data.featureImageURL,
                    bundleResourceName: data.featureImageResourceName,
                    placement: .mediaSheetHero(
                        height: MarineLifeMediaTagPresentation.speciesRowThumbnailHeight,
                        cornerRadius: 8
                    )
                )
                .frame(
                    width: MarineLifeMediaTagPresentation.speciesRowThumbnailWidth,
                    height: MarineLifeMediaTagPresentation.speciesRowThumbnailHeight
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(data.commonName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)

                Text(data.sightingCountLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(data.commonName), \(data.sightingCountLabel)")
    }
}
