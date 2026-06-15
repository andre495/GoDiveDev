import SwiftUI

/// 2×2 highlight grid for linked dive rollups on **`TripDetailView`**.
struct TripDetailTripStatsSection: View {
    let tiles: [DiveTripStatTile]
    var onOpenDive: ((UUID) -> Void)? = nil

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: HomeLifetimeStatsTilesLayout.gridSpacing),
                GridItem(.flexible(), spacing: HomeLifetimeStatsTilesLayout.gridSpacing),
            ],
            spacing: HomeLifetimeStatsTilesLayout.gridSpacing
        ) {
            ForEach(tiles) { tile in
                TripDetailStatTile(tile: tile, onOpenDive: onOpenDive)
            }
        }
        .frame(height: HomeLifetimeStatsTilesLayout.gridHeight(tileCount: tiles.count))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, TripDetailMediaGalleryPresentation.previewHorizontalInset)
        .accessibilityIdentifier("TripDetail.Stats")
    }
}

private struct TripDetailStatTile: View {
    let tile: DiveTripStatTile
    var onOpenDive: ((UUID) -> Void)?

    private var isTappable: Bool {
        tile.linkedDiveID != nil && onOpenDive != nil
    }

    private var showsFootnote: Bool {
        !tile.footnote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            if isTappable, let diveID = tile.linkedDiveID, let onOpenDive {
                Button {
                    onOpenDive(diveID)
                } label: {
                    tileContent
                }
                .buttonStyle(.plain)
            } else {
                tileContent
            }
        }
    }

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                Image(systemName: tile.systemImage)
                    .font(.system(size: HomeLifetimeStatsTilesLayout.titleFontSize, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .accessibilityHidden(true)

                Text(tile.title)
                    .font(.system(size: HomeLifetimeStatsTilesLayout.titleFontSize, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                if isTappable {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.mutedText)
                        .accessibilityHidden(true)
                }
            }

            Text(tile.value)
                .font(.system(size: HomeLifetimeStatsTilesLayout.valueFontSize, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsFootnote {
                Text(tile.footnote)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.mutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(HomeLifetimeStatsTilesLayout.statTilePadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: HomeLifetimeStatsTilesLayout.statTileHeight, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceMuted.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.Colors.tabUnselected.opacity(0.14), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isTappable ? .isButton : [])
        .accessibilityHint(isTappable ? "Opens dive activity" : "")
        .accessibilityIdentifier("TripDetail.Stats.\(tile.id)")
    }

    private var accessibilityLabel: String {
        "\(tile.title), \(tile.value)\(showsFootnote ? ", \(tile.footnote)" : "")"
    }
}
