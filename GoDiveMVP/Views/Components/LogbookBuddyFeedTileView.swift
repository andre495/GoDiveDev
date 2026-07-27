import SwiftUI

/// Layout tokens for Buddy Feed activity tiles.
enum LogbookBuddyFeedTileLayout {
    static let heroHeight: CGFloat = 128
    static let cardCornerRadius: CGFloat = 12
    static let contentPadding: CGFloat = AppTheme.Spacing.sm
    static let contentSpacing: CGFloat = 4
}

/// Buddy Feed card: hero depth chart or GPS track + key stats + friend attribution.
struct LogbookBuddyFeedTileView: View, Equatable {
    let row: LogbookBuddyFeedPresentation.Row

    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @State private var swimTrackCoordinates: [DiveCoordinate] = []

    static func == (lhs: LogbookBuddyFeedTileView, rhs: LogbookBuddyFeedTileView) -> Bool {
        lhs.row == rhs.row
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroHeader
            tileBody
        }
        .background {
            RoundedRectangle(cornerRadius: LogbookBuddyFeedTileLayout.cardCornerRadius, style: .continuous)
                .fill(AppListTileCardChrome.fill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: LogbookBuddyFeedTileLayout.cardCornerRadius, style: .continuous)
                .stroke(AppListTileCardChrome.stroke, lineWidth: AppListTileCardChrome.strokeWidth)
        }
        .clipShape(RoundedRectangle(cornerRadius: LogbookBuddyFeedTileLayout.cardCornerRadius, style: .continuous))
        .task(id: row.id) {
            await loadHeroData()
        }
    }

    @ViewBuilder
    private var heroHeader: some View {
        ZStack(alignment: .topLeading) {
            switch row.dive.resolvedActivityKind {
            case .scubaDive:
                diveDepthHero
            case .snorkel:
                snorkelMapHero
            }

            activityKindBadge
                .padding(LogbookBuddyFeedTileLayout.contentPadding)
        }
        .frame(height: LogbookBuddyFeedTileLayout.heroHeight)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.screenBackgroundGradient)
    }

    @ViewBuilder
    private var diveDepthHero: some View {
        FriendSharedDepthProfileChartView(
            dive: row.dive,
            allowsInteraction: false,
            animatesWaterFill: false,
            chromeStyle: .edgeToEdge
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var snorkelMapHero: some View {
        if swimTrackCoordinates.count >= 2 {
            SnorkelSwimTrackMapView(
                trackCoordinates: swimTrackCoordinates,
                layoutHeight: LogbookBuddyFeedTileLayout.heroHeight,
                cameraFitting: .compact,
                isUserInteractionEnabled: false
            )
        } else if let latitude = row.dive.entryLatitude,
                  let longitude = row.dive.entryLongitude {
            SnorkelSwimTrackMapView(
                trackCoordinates: [DiveCoordinate(latitude: latitude, longitude: longitude)],
                layoutHeight: LogbookBuddyFeedTileLayout.heroHeight,
                cameraFitting: .compact,
                isUserInteractionEnabled: false
            )
        } else {
            heroPlaceholder(systemName: "map")
        }
    }

    private func heroPlaceholder(systemName: String) -> some View {
        AppTheme.Colors.screenBackgroundGradient
            .overlay {
                Image(systemName: systemName)
                    .font(.title2)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
    }

    private var activityKindBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: activityKindSymbolName)
                .font(.caption2.weight(.semibold))
            Text(activityKindLabel)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial, in: Capsule())
        .accessibilityLabel(activityKindLabel)
    }

    private var activityKindSymbolName: String {
        switch row.dive.resolvedActivityKind {
        case .scubaDive:
            LogbookActivityRowPresentation.scubaDiveLeadingSymbolName
        case .snorkel:
            LogbookActivityRowPresentation.snorkelLeadingSymbolName
        }
    }

    private var activityKindLabel: String {
        switch row.dive.resolvedActivityKind {
        case .scubaDive:
            "Dive"
        case .snorkel:
            "Snorkel"
        }
    }

    private var tileBody: some View {
        VStack(alignment: .leading, spacing: LogbookBuddyFeedTileLayout.contentSpacing) {
            Text(LogbookBuddyFeedPresentation.tileSiteTitle(for: row.dive))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(2)

            if let regionCountry = LogbookBuddyFeedPresentation.tileRegionCountryLine(for: row.dive) {
                Text(regionCountry)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
            }

            Text(
                LogbookBuddyFeedPresentation.tileStatsLine(
                    for: row.dive,
                    unitSystem: diveDisplayUnitSystem
                )
            )
            .font(.caption)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
        }
        .padding(LogbookBuddyFeedTileLayout.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func loadHeroData() async {
        let dive = row.dive
        swimTrackCoordinates = GoDiveSharedDiveProjectionMapping.decodedSwimTrackCoordinates(from: dive)
    }
}
