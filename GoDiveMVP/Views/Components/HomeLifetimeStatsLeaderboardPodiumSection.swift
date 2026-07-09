import SwiftUI

struct HomeLifetimeStatsLeaderboardPodiumSection: View {
    let kind: HomeLifetimeStatsLeaderboardKind
    let unitSystem: DiveDisplayUnitSystem
    let diveStatsByID: [UUID: HomeDiveStatsInput]
    let diveRows: [DiveLogbookRowDisplayData]
    let siteEntries: [HomeLifetimeStatsLeaderboardPresentation.SiteEntry]
    let speciesEntries: [HomeLifetimeStatsLeaderboardPresentation.SpeciesEntry]
    let speciesRowData: [HomeLifetimeStatsLeaderboardPresentation.SpeciesRowDisplayData]
    let accessibilityRootIdentifier: String
    let onOpenDive: (UUID) -> Void
    let onOpenSite: (UUID) -> Void
    let onOpenSpecies: (String) -> Void

    private var entryCount: Int {
        switch kind {
        case .deepestDives, .longestDives:
            return diveRows.count
        case .topSites:
            return siteEntries.count
        case .topSpecies:
            return speciesEntries.count
        }
    }

    private var podiumSlots: [HomeLifetimeStatsLeaderboardLayout.PodiumSlot] {
        HomeLifetimeStatsLeaderboardLayout.podiumSlots(entryCount: entryCount)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: HomeLifetimeStatsLeaderboardLayout.podiumSlotSpacing) {
            ForEach(Array(podiumSlots.enumerated()), id: \.offset) { _, slot in
                podiumSlot(for: slot)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: HomeLifetimeStatsLeaderboardLayout.podiumSectionMinHeight, alignment: .bottom)
        .padding(.vertical, AppTheme.Spacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(accessibilityRootIdentifier).Podium")
    }

    @ViewBuilder
    private func podiumSlot(for slot: HomeLifetimeStatsLeaderboardLayout.PodiumSlot) -> some View {
        switch kind {
        case .deepestDives, .longestDives:
            if diveRows.indices.contains(slot.rank - 1) {
                let row = diveRows[slot.rank - 1]
                HomeLifetimeStatsLeaderboardPodiumSlot(
                    rank: slot.rank,
                    title: divePodiumTitle(for: row),
                    metricLabel: divePodiumMetric(for: row),
                    previewContent: {
                        Image(systemName: kind == .deepestDives ? "arrow.down.to.line" : "clock.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.accent)
                            .frame(width: 44, height: 44)
                            .background {
                                Circle()
                                    .fill(AppTheme.Colors.surfaceElevated)
                            }
                    },
                    action: { onOpenDive(row.id) },
                    accessibilityIdentifier: "\(accessibilityRootIdentifier).Podium.\(slot.rank)"
                )
            }
        case .topSites:
            if let entry = siteEntries.first(where: { $0.rank == slot.rank }) {
                let opensSite = entry.siteID != nil
                HomeLifetimeStatsLeaderboardPodiumSlot(
                    rank: slot.rank,
                    title: entry.name,
                    metricLabel: HomeLifetimeStatsLeaderboardPresentation.metricCaption(
                        for: .topSites,
                        count: entry.visitCount
                    ),
                    previewContent: {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.accent)
                            .frame(width: 44, height: 44)
                            .background {
                                Circle()
                                    .fill(AppTheme.Colors.surfaceElevated)
                            }
                    },
                    action: opensSite ? { onOpenSite(entry.siteID!) } : nil,
                    accessibilityIdentifier: "\(accessibilityRootIdentifier).Podium.\(slot.rank)"
                )
            }
        case .topSpecies:
            if let entry = speciesEntries.first(where: { $0.rank == slot.rank }),
               let row = speciesRowData.first(where: { $0.marineLifeUUID == entry.marineLifeUUID }) {
                HomeLifetimeStatsLeaderboardPodiumSlot(
                    rank: slot.rank,
                    title: row.commonName,
                    metricLabel: row.sightingCountLabel,
                    previewContent: {
                        if row.showsPreviewImage {
                            FieldGuideMarineLifeCatalogImage(
                                imageURLString: row.featureImageURL,
                                bundleResourceName: row.featureImageResourceName,
                                placement: .mediaSheetHero(height: 44, cornerRadius: 22)
                            )
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "fish.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.accent)
                                .frame(width: 44, height: 44)
                                .background {
                                    Circle()
                                        .fill(AppTheme.Colors.surfaceElevated)
                                }
                        }
                    },
                    action: { onOpenSpecies(row.marineLifeUUID) },
                    accessibilityIdentifier: "\(accessibilityRootIdentifier).Podium.\(slot.rank)"
                )
            }
        }
    }

    private func divePodiumTitle(for row: DiveLogbookRowDisplayData) -> String {
        guard let dive = diveStatsByID[row.id] else { return row.displayName }
        return HomeLifetimeStatsLeaderboardPresentation.divePodiumTitle(for: dive)
    }

    private func divePodiumMetric(for row: DiveLogbookRowDisplayData) -> String {
        guard let dive = diveStatsByID[row.id] else { return row.detailLine }
        return HomeLifetimeStatsLeaderboardPresentation.divePodiumMetricLabel(
            dive: dive,
            kind: kind,
            unitSystem: unitSystem
        )
    }
}

private struct HomeLifetimeStatsLeaderboardPodiumSlot<Preview: View>: View {
    let rank: Int
    let title: String
    let metricLabel: String
    @ViewBuilder let previewContent: () -> Preview
    let action: (() -> Void)?
    let accessibilityIdentifier: String

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    slotContent
                }
                .buttonStyle(.plain)
            } else {
                slotContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), rank \(rank), \(metricLabel)")
        .accessibilityHint(action != nil ? "Opens details" : "")
        .accessibilityAddTraits(action != nil ? .isButton : [])
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var slotContent: some View {
        VStack(spacing: 6) {
            Image(systemName: HomeLifetimeStatsLeaderboardLayout.rankMedalSymbol(for: rank))
                .font(.system(size: HomeLifetimeStatsLeaderboardLayout.podiumMedalIconSize, weight: .semibold))
                .foregroundStyle(medalColor)
                .accessibilityHidden(true)

            previewContent()

            Text(title)
                .font(rank == 1 ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(metricLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            pedestal
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var pedestal: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(pedestalFill)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(pedestalStroke, lineWidth: 1)
            }
            .overlay {
                Text("\(rank)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(pedestalNumberColor)
            }
            .frame(height: HomeLifetimeStatsLeaderboardLayout.pedestalHeight(for: rank))
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var medalColor: Color {
        switch rank {
        case 1:
            return Color(red: 0.92, green: 0.74, blue: 0.18)
        case 2:
            return Color(red: 0.72, green: 0.75, blue: 0.78)
        case 3:
            return Color(red: 0.78, green: 0.52, blue: 0.28)
        default:
            return AppTheme.Colors.mutedText
        }
    }

    private var pedestalFill: Color {
        switch rank {
        case 1:
            return Color(red: 0.92, green: 0.74, blue: 0.18).opacity(0.22)
        case 2:
            return Color(red: 0.72, green: 0.75, blue: 0.78).opacity(0.22)
        default:
            return Color(red: 0.78, green: 0.52, blue: 0.28).opacity(0.22)
        }
    }

    private var pedestalStroke: Color {
        switch rank {
        case 1:
            return Color(red: 0.92, green: 0.74, blue: 0.18).opacity(0.45)
        case 2:
            return Color(red: 0.72, green: 0.75, blue: 0.78).opacity(0.45)
        default:
            return Color(red: 0.78, green: 0.52, blue: 0.28).opacity(0.45)
        }
    }

    private var pedestalNumberColor: Color {
        switch rank {
        case 1:
            return Color(red: 0.72, green: 0.56, blue: 0.08)
        case 2:
            return Color(red: 0.45, green: 0.48, blue: 0.52)
        default:
            return Color(red: 0.58, green: 0.36, blue: 0.16)
        }
    }
}

struct HomeLifetimeStatsLeaderboardRankBadge: View {
    let rank: Int

    var body: some View {
        Text("\(rank)")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .frame(width: HomeLifetimeStatsLeaderboardLayout.listRankBadgeWidth)
            .accessibilityHidden(true)
    }
}
