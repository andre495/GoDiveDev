import SwiftUI

/// Layout tokens for Buddy Feed activity tiles.
enum LogbookBuddyFeedTileLayout {
    static let heroHeight: CGFloat = 256
    static let cardCornerRadius: CGFloat = 12
    static let contentPadding: CGFloat = AppTheme.Spacing.sm
    static let contentSpacing: CGFloat = 4
}

/// Which portion of a Buddy Feed tile to render (hero is isolated from navigation when swipeable).
enum LogbookBuddyFeedTilePart {
    case full
    case hero
    case body
}

/// Buddy Feed card chrome (background, stroke, clip).
struct LogbookBuddyFeedTileCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: LogbookBuddyFeedTileLayout.cardCornerRadius, style: .continuous)
                    .fill(AppListTileCardChrome.fill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: LogbookBuddyFeedTileLayout.cardCornerRadius, style: .continuous)
                    .stroke(AppListTileCardChrome.stroke, lineWidth: AppListTileCardChrome.strokeWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: LogbookBuddyFeedTileLayout.cardCornerRadius, style: .continuous))
    }
}

extension View {
    func buddyFeedTileCardStyle() -> some View {
        modifier(LogbookBuddyFeedTileCardStyle())
    }
}

/// Wraps navigation so horizontal hero paging does not compete with **`NavigationLink`**.
struct LogbookBuddyFeedNavigableTile<BodyLink: View>: View {
    let row: LogbookBuddyFeedPresentation.Row
    @ViewBuilder let bodyLink: (_ isolatesHeroFromNavigation: Bool) -> BodyLink

    private var isolatesHeroFromNavigation: Bool {
        LogbookBuddyFeedPresentation.showsHeroPager(for: row.dive)
    }

    var body: some View {
        Group {
            if isolatesHeroFromNavigation {
                VStack(alignment: .leading, spacing: 0) {
                    LogbookBuddyFeedTileView(row: row, part: .hero)
                    bodyLink(true)
                }
            } else {
                bodyLink(false)
            }
        }
        .buddyFeedTileCardStyle()
    }
}

/// Buddy Feed card: paged hero (shared media → depth chart / GPS track) + key stats.
struct LogbookBuddyFeedTileView: View, Equatable {
    let row: LogbookBuddyFeedPresentation.Row
    var part: LogbookBuddyFeedTilePart = .full

    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @State private var swimTrackCoordinates: [DiveCoordinate] = []

    private var heroPages: [LogbookBuddyFeedPresentation.HeroPage] {
        LogbookBuddyFeedPresentation.heroPages(for: row.dive)
    }

    static func == (lhs: LogbookBuddyFeedTileView, rhs: LogbookBuddyFeedTileView) -> Bool {
        lhs.row == rhs.row && lhs.part == rhs.part
    }

    var body: some View {
        Group {
            switch part {
            case .full:
                VStack(alignment: .leading, spacing: 0) {
                    heroHeader
                    tileBody
                }
            case .hero:
                heroHeader
            case .body:
                tileBody
            }
        }
        .modifier(ApplyBuddyFeedTileCardStyle(apply: part == .full))
        .task(id: row.id) {
            await loadHeroData()
        }
    }

    @ViewBuilder
    private var heroHeader: some View {
        ZStack(alignment: .topLeading) {
            heroPager

            activityKindBadge
                .padding(LogbookBuddyFeedTileLayout.contentPadding)
        }
        .frame(height: LogbookBuddyFeedTileLayout.heroHeight)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.screenBackgroundGradient)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Activity preview")
        .accessibilityHint(
            LogbookBuddyFeedPresentation.showsHeroPager(for: row.dive)
                ? "Swipe horizontally between photo and activity chart"
                : ""
        )
    }

    @ViewBuilder
    private var heroPager: some View {
        if LogbookBuddyFeedPresentation.showsHeroPager(for: row.dive) {
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(heroPages) { page in
                            heroPageContent(page)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .id(page.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            }
        } else if let page = heroPages.first {
            heroPageContent(page)
        }
    }

    @ViewBuilder
    private func heroPageContent(_ page: LogbookBuddyFeedPresentation.HeroPage) -> some View {
        switch page {
        case .media(let preview):
            LogbookBuddyFeedMediaHeroPage(previewURL: preview.previewURL)
        case .activityVisualization:
            activityVisualizationHero
        case .placeholder:
            heroPlaceholder(systemName: placeholderSystemImageName)
        }
    }

    private var placeholderSystemImageName: String {
        switch row.dive.resolvedActivityKind {
        case .scubaDive:
            "chart.line.uptrend.xyaxis"
        case .snorkel:
            "map"
        }
    }

    @ViewBuilder
    private var activityVisualizationHero: some View {
        switch row.dive.resolvedActivityKind {
        case .scubaDive:
            diveDepthHero
        case .snorkel:
            snorkelMapHero
        }
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
        .allowsHitTesting(false)
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
        .contentShape(Rectangle())
    }

    @MainActor
    private func loadHeroData() async {
        let dive = row.dive
        swimTrackCoordinates = GoDiveSharedDiveProjectionMapping.decodedSwimTrackCoordinates(from: dive)
    }
}

private struct ApplyBuddyFeedTileCardStyle: ViewModifier {
    let apply: Bool

    func body(content: Content) -> some View {
        if apply {
            content.buddyFeedTileCardStyle()
        } else {
            content
        }
    }
}

/// Full-bleed shared media page inside a Buddy Feed tile hero.
struct LogbookBuddyFeedMediaHeroPage: View {
    let previewURL: String

    var body: some View {
        AsyncImage(url: URL(string: previewURL)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                heroPlaceholder
            default:
                AppTheme.Colors.surfaceElevated
                    .overlay { ProgressView() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityLabel("Shared activity photo")
    }

    private var heroPlaceholder: some View {
        AppTheme.Colors.surfaceElevated
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
    }
}
