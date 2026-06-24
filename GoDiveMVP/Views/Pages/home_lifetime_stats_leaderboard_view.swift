import SwiftData
import SwiftUI

/// Ranked top-five list for a Home lifetime stat tile (deepest, longest, sites, species).
struct HomeLifetimeStatsLeaderboardView: View {
    let kind: HomeLifetimeStatsLeaderboardKind
    let diveStatsInputs: [HomeDiveStatsInput]
    let activities: [DiveActivity]
    let unitSystem: DiveDisplayUnitSystem
    let automaticallyRenumberDives: Bool
    let sightings: [HomeLifetimeStatsPresentation.SightingCountInput]
    let onOpenDive: (UUID) -> Void
    let onOpenSite: (UUID) -> Void
    let onOpenSpecies: (String) -> Void

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
        switch kind {
        case .deepestDives, .longestDives:
            HomeLifetimeStatsLeaderboardDiveRows(
                rows: diveRows,
                onOpenDive: onOpenDive
            )
        case .topSites:
            ForEach(siteEntries) { entry in
                HomeLifetimeStatsLeaderboardMetricRow(
                    rank: entry.rank,
                    title: entry.name,
                    caption: HomeLifetimeStatsLeaderboardPresentation.metricCaption(
                        for: kind,
                        count: entry.visitCount
                    ),
                    systemImage: "mappin.circle.fill",
                    action: entry.siteID.map { siteID in { onOpenSite(siteID) } }
                )
                .accessibilityIdentifier("\(accessibilityRootIdentifier).Row.\(entry.rank)")
            }
        case .topSpecies:
            ForEach(speciesEntries) { entry in
                HomeLifetimeStatsLeaderboardMetricRow(
                    rank: entry.rank,
                    title: entry.commonName,
                    caption: HomeLifetimeStatsLeaderboardPresentation.metricCaption(
                        for: kind,
                        count: entry.sightingCount
                    ),
                    systemImage: "fish.fill",
                    action: { onOpenSpecies(entry.marineLifeUUID) }
                )
                .accessibilityIdentifier("\(accessibilityRootIdentifier).Row.\(entry.rank)")
            }
        }
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

private struct HomeLifetimeStatsLeaderboardDiveRows: View {
    let rows: [DiveLogbookRowDisplayData]
    let onOpenDive: (UUID) -> Void

    var body: some View {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
            Button {
                onOpenDive(row.id)
            } label: {
                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                    HomeLifetimeStatsLeaderboardRankBadge(rank: index + 1)

                    LogbookActivityRow(data: row)
                        .equatable()
                }
            }
            .buttonStyle(.plain)
            .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }
}

private struct HomeLifetimeStatsLeaderboardMetricRow: View {
    let rank: Int
    let title: String
    let caption: String
    let systemImage: String
    let action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            HomeLifetimeStatsLeaderboardRankBadge(rank: rank)

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.Colors.accent.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                if !caption.isEmpty {
                    Text(caption)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .accessibilityHidden(true)
            }
        }
        .padding(LogbookActivityRowLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if caption.isEmpty {
            return "Rank \(rank), \(title)"
        }
        return "Rank \(rank), \(title), \(caption)"
    }
}

private struct HomeLifetimeStatsLeaderboardRankBadge: View {
    let rank: Int

    var body: some View {
        Text("\(rank)")
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.Colors.accent)
            .frame(width: 28, height: 28)
            .background {
                Circle()
                    .fill(AppTheme.Colors.accent.opacity(0.14))
            }
            .accessibilityHidden(true)
    }
}
