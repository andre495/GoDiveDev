import SwiftUI

/// Layout tokens for Buddy Feed social-style activity posts.
enum LogbookBuddyFeedTileLayout {
    static let heroHeight: CGFloat = 256
    static let cardCornerRadius: CGFloat = 12
    static let contentPadding: CGFloat = AppTheme.Spacing.sm
    static let contentSpacing: CGFloat = 4
    static let postHeaderAvatarDiameter: CGFloat = 36
    static let taggedBuddyAvatarDiameter: CGFloat = 28
    static let taggedBuddyAvatarOverlap: CGFloat = 10
    static let actionBarIconSize: CGFloat = 28
    /// Slightly larger like / comment glyphs on friend-shared activity detail.
    static let detailActionBarIconSize: CGFloat = 34
    static let pageDotSize: CGFloat = 6
    static let pageDotSpacing: CGFloat = 6
}

/// Which portion of a Buddy Feed post to render (hero/actions stay outside **`NavigationLink`**).
enum LogbookBuddyFeedTilePart {
    case full
    case hero
    /// Caption + “with” tagged row (standalone / full tile).
    case body
    /// Caption only — tagged row is rendered outside **`NavigationLink`** in the navigable tile.
    case caption
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

/// Social-style Buddy Feed post: header + hero + caption body + bottom like bar.
/// Hero, “with” tags, and like stay outside **`NavigationLink`** so those taps do not compete with navigation.
struct LogbookBuddyFeedNavigableTile<BodyLink: View>: View {
    let row: LogbookBuddyFeedPresentation.Row
    var avatarLookup: BuddyFeedAvatarLookup = .empty
    var onOpenFriendProfile: (() -> Void)? = nil
    var onToggleLike: (() -> Void)? = nil
    var onOpenComments: (() -> Void)? = nil
    /// Opens the shared activity Map panel scrolled to tagged buddies.
    var onOpenTaggedBuddies: (() -> Void)? = nil
    @ViewBuilder let bodyLink: () -> BodyLink

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogbookBuddyFeedPostHeaderView(
                row: row,
                onOpenFriendProfile: onOpenFriendProfile
            )
            LogbookBuddyFeedTileView(row: row, part: .hero, avatarLookup: avatarLookup)
            bodyLink()
            if !LogbookBuddyFeedPresentation.feedTaggedBuddies(for: row.dive).isEmpty {
                LogbookBuddyFeedTaggedDiversRow(
                    dive: row.dive,
                    avatarLookup: avatarLookup,
                    appliesContentPadding: true
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onOpenTaggedBuddies?()
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens activity and shows tagged buddies")
            }
            Divider()
                .overlay(AppTheme.Colors.tabUnselected.opacity(0.18))
                .padding(.horizontal, LogbookBuddyFeedTileLayout.contentPadding)
            LogbookBuddyFeedPostActionBar(
                isLiked: row.currentUserHasLiked,
                likeCount: row.likeCount,
                commentCount: row.commentCount,
                onToggleLike: onToggleLike,
                onOpenComments: onOpenComments
            )
        }
        .buddyFeedTileCardStyle()
    }
}

/// Avatar + name + relative time header for a Buddy Feed post.
struct LogbookBuddyFeedPostHeaderView: View {
    let row: LogbookBuddyFeedPresentation.Row
    var onOpenFriendProfile: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            profileControl {
                FriendSharedMapOwnerAvatarView(
                    displayName: row.friendDisplayName,
                    photoURL: row.friendPhotoURL,
                    diameter: LogbookBuddyFeedTileLayout.postHeaderAvatarDiameter
                )
            }

            VStack(alignment: .leading, spacing: 1) {
                profileControl {
                    Text(row.friendDisplayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                }

                Text(LogbookBuddyFeedPresentation.postActivityVerb(for: row.dive))
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            if let timestamp = LogbookBuddyFeedPresentation.postTimestampText(for: row.dive) {
                Text(timestamp)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .accessibilityLabel("Posted \(timestamp)")
            }
        }
        .padding(.horizontal, LogbookBuddyFeedTileLayout.contentPadding)
        .padding(.top, LogbookBuddyFeedTileLayout.contentPadding)
        .padding(.bottom, AppTheme.Spacing.sm)
    }

    @ViewBuilder
    private func profileControl<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        if let onOpenFriendProfile {
            // `.borderless` so List rows don’t swallow the tap (`.plain` often fails in List).
            Button(action: onOpenFriendProfile, label: label)
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
                .accessibilityLabel(row.friendDisplayName)
                .accessibilityHint("Opens friend profile")
        } else {
            label()
                .accessibilityLabel(row.friendDisplayName)
        }
    }
}

/// Like + comment controls for a Buddy Feed post (optimistic UI; parent persists to Firestore).
struct LogbookBuddyFeedPostActionBar: View {
    let isLiked: Bool
    let likeCount: Int
    var commentCount: Int = 0
    var showsCommentControl: Bool = true
    /// Feed tiles inset the bar; detail map social uses `false` to align with panel content.
    var appliesContentPadding: Bool = true
    var iconSize: CGFloat = LogbookBuddyFeedTileLayout.actionBarIconSize
    var onToggleLike: (() -> Void)? = nil
    var onOpenComments: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Button {
                guard onToggleLike != nil else { return }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                    onToggleLike?()
                }
            } label: {
                HStack(spacing: 6) {
                    BuddyFeedOkayHandIcon(isLiked: isLiked, size: iconSize)

                    if let tally = LogbookBuddyFeedPresentation.likeCountLabel(
                        count: likeCount,
                        isLikedByCurrentUser: isLiked
                    ) {
                        Text(tally)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(
                                isLiked
                                    ? AppTheme.Colors.accent
                                    : AppTheme.Colors.secondaryText
                            )
                            .contentTransition(.numericText())
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(likeAccessibilityLabel)
            }
            .buttonStyle(.plain)
            .disabled(onToggleLike == nil)

            if showsCommentControl {
                Button {
                    onOpenComments?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: LogbookBuddyFeedPresentation.commentSymbolName)
                            .font(.system(size: max(iconSize - 4, 16), weight: .medium))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .frame(width: iconSize, height: iconSize)

                        if let tally = LogbookBuddyFeedPresentation.commentCountLabel(count: commentCount) {
                            Text(tally)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                .contentTransition(.numericText())
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(commentAccessibilityLabel)
                }
                .buttonStyle(.plain)
                .disabled(onOpenComments == nil)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, appliesContentPadding ? LogbookBuddyFeedTileLayout.contentPadding : 0)
        .padding(.top, appliesContentPadding ? AppTheme.Spacing.sm : 0)
        .padding(.bottom, appliesContentPadding ? LogbookBuddyFeedTileLayout.contentPadding : 0)
    }

    private var likeAccessibilityLabel: String {
        let action = LogbookBuddyFeedPresentation.likeAccessibilityLabel(isLiked: isLiked)
        if likeCount > 0 {
            return "\(action), \(likeCount) likes"
        }
        return action
    }

    private var commentAccessibilityLabel: String {
        if commentCount > 0 {
            return "\(LogbookBuddyFeedPresentation.commentAccessibilityLabel), \(commentCount)"
        }
        return LogbookBuddyFeedPresentation.commentAccessibilityLabel
    }
}

/// Buddy Feed post content: paged hero (shared media → depth chart / GPS track) + caption body.
struct LogbookBuddyFeedTileView: View, Equatable {
    let row: LogbookBuddyFeedPresentation.Row
    var part: LogbookBuddyFeedTilePart = .full
    var avatarLookup: BuddyFeedAvatarLookup = .empty

    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @State private var swimTrackCoordinates: [DiveCoordinate] = []
    @State private var isTileVisible = false
    @State private var visibleHeroPageID: String?

    private var heroPages: [LogbookBuddyFeedPresentation.HeroPage] {
        LogbookBuddyFeedPresentation.heroPages(for: row.dive)
    }

    static func == (lhs: LogbookBuddyFeedTileView, rhs: LogbookBuddyFeedTileView) -> Bool {
        lhs.row == rhs.row
            && lhs.part == rhs.part
            && lhs.avatarLookup == rhs.avatarLookup
    }

    var body: some View {
        Group {
            switch part {
            case .full:
                VStack(alignment: .leading, spacing: 0) {
                    heroHeader
                    tileBody(includesTaggedBuddies: true)
                }
            case .hero:
                heroHeader
            case .body:
                tileBody(includesTaggedBuddies: true)
            case .caption:
                tileBody(includesTaggedBuddies: false)
            }
        }
        .modifier(ApplyBuddyFeedTileCardStyle(apply: part == .full))
        .onAppear { isTileVisible = true }
        .onDisappear {
            isTileVisible = false
            visibleHeroPageID = nil
        }
        .task(id: row.id) {
            await loadHeroData()
        }
        .task(id: buddyFeedFeaturedContentPrefetchToken) {
            guard isTileVisible else { return }
            var urls: [String] = []
            if let photo = FriendSharedMediaPresentation.buddyFeedFeaturedPhotoContentPrefetchURL(
                for: row.dive
            ) {
                urls.append(photo)
            }
            if let video = FriendSharedMediaPresentation.buddyFeedFeaturedVideoContentPrefetchURL(
                for: row.dive
            ) {
                urls.append(video)
            }
            guard !urls.isEmpty else { return }
            await FriendSharedMediaPresentation.prefetchContentIfAllowed(urls: urls)
        }
    }

    private var buddyFeedFeaturedContentPrefetchToken: String {
        "\(row.id)-\(isTileVisible)"
    }

    @ViewBuilder
    private var heroHeader: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                heroPager

                activityKindBadge
                    .padding(LogbookBuddyFeedTileLayout.contentPadding)
            }
            .frame(height: LogbookBuddyFeedTileLayout.heroHeight)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.screenBackgroundGradient)
            .clipped()
            .contentShape(Rectangle())
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Activity preview")
            .accessibilityHint(
                LogbookBuddyFeedPresentation.showsHeroPager(for: row.dive)
                    ? "Swipe horizontally between photo and activity chart"
                    : ""
            )

            if LogbookBuddyFeedPresentation.showsHeroPager(for: row.dive) {
                heroPageDots
                    .padding(.top, AppTheme.Spacing.sm)
                    .padding(.bottom, 2)
            }
        }
    }

    private var heroPageDots: some View {
        HStack(spacing: LogbookBuddyFeedTileLayout.pageDotSpacing) {
            ForEach(heroPages) { page in
                Circle()
                    .fill(
                        (visibleHeroPageID ?? heroPages.first?.id) == page.id
                            ? AppTheme.Colors.accent
                            : AppTheme.Colors.tabUnselected.opacity(0.35)
                    )
                    .frame(
                        width: LogbookBuddyFeedTileLayout.pageDotSize,
                        height: LogbookBuddyFeedTileLayout.pageDotSize
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var heroPager: some View {
        if LogbookBuddyFeedPresentation.showsHeroPager(for: row.dive) {
            GeometryReader { geometry in
                let pageSize = LogbookBuddyFeedHeroPagerPresentation.pageSize(
                    containerSize: geometry.size
                )
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(heroPages) { page in
                            heroPageContent(page)
                                .frame(width: pageSize.width, height: pageSize.height)
                                // Aspect-fill media / chart drawing can exceed the page bounds —
                                // clip so page 1 never paints into the depth chart on page 2.
                                .compositingGroup()
                                .clipped()
                                .contentShape(Rectangle())
                                .id(page.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .scrollPosition(id: $visibleHeroPageID)
                .scrollClipDisabled(!LogbookBuddyFeedHeroPagerPresentation.clipsOverflowingPageContent)
                .clipped()
                .onAppear {
                    if visibleHeroPageID == nil {
                        visibleHeroPageID = heroPages.first?.id
                    }
                }
            }
            .clipped()
        } else if let page = heroPages.first {
            heroPageContent(page)
                .clipped()
        }
    }

    @ViewBuilder
    private func heroPageContent(_ page: LogbookBuddyFeedPresentation.HeroPage) -> some View {
        switch page {
        case .media(let item):
            LogbookBuddyFeedMediaHeroPage(
                item: item,
                isPlaybackActive: shouldAutoplayFeaturedVideo(for: page, item: item)
            )
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
        .clipped()
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

    private func tileBody(includesTaggedBuddies: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
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

            if includesTaggedBuddies,
               !LogbookBuddyFeedPresentation.feedTaggedBuddies(for: row.dive).isEmpty
            {
                LogbookBuddyFeedTaggedDiversRow(
                    dive: row.dive,
                    avatarLookup: avatarLookup,
                    appliesContentPadding: false
                )
            }
        }
        .padding(.horizontal, LogbookBuddyFeedTileLayout.contentPadding)
        .padding(.top, AppTheme.Spacing.sm)
        .padding(.bottom, AppTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @MainActor
    private func loadHeroData() async {
        let dive = row.dive
        swimTrackCoordinates = GoDiveSharedDiveProjectionMapping.decodedSwimTrackCoordinates(from: dive)
    }

    private func shouldAutoplayFeaturedVideo(
        for page: LogbookBuddyFeedPresentation.HeroPage,
        item: FriendSharedMediaPresentation.DisplayItem
    ) -> Bool {
        guard isTileVisible, item.kind == .video else { return false }
        let activePageID = visibleHeroPageID ?? heroPages.first?.id
        return activePageID == page.id
    }
}

/// “with” overlapping avatars + names on a Buddy Feed post.
struct LogbookBuddyFeedTaggedDiversRow: View {
    let dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    var avatarLookup: BuddyFeedAvatarLookup = .empty
    var appliesContentPadding: Bool = false

    var body: some View {
        let visible = LogbookBuddyFeedPresentation.visibleFeedTaggedBuddies(for: dive)
        let overflow = LogbookBuddyFeedPresentation.overflowTaggedBuddyCount(for: dive)
        let namesLine = LogbookBuddyFeedPresentation.withTaggedBuddyNamesLine(for: dive)

        return HStack(alignment: .center, spacing: 6) {
            Text(LogbookBuddyFeedPresentation.withTaggedDiversLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.Colors.secondaryText)

            HStack(spacing: -LogbookBuddyFeedTileLayout.taggedBuddyAvatarOverlap) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, buddy in
                    let resolved = BuddyFeedAvatarPresentation.resolve(
                        firebaseUID: buddy.firebaseUID,
                        lookup: avatarLookup
                    )
                    FriendSharedMapOwnerAvatarView(
                        displayName: buddy.displayName,
                        photoURL: resolved.photoURL,
                        diameter: LogbookBuddyFeedTileLayout.taggedBuddyAvatarDiameter,
                        showsGoDiveUserPin: buddy.showsGoDiveUserPin,
                        localProfilePhoto: resolved.localProfilePhoto
                    )
                    .overlay {
                        Circle()
                            .stroke(AppListTileCardChrome.fill, lineWidth: 2)
                    }
                    .zIndex(Double(visible.count - index))
                }
            }
            .accessibilityHidden(true)

            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            } else if let namesLine {
                Text(namesLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.horizontal, appliesContentPadding ? LogbookBuddyFeedTileLayout.contentPadding : 0)
        .padding(.bottom, appliesContentPadding ? AppTheme.Spacing.sm : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText(visible: visible, overflow: overflow))
    }

    private func accessibilityLabelText(
        visible: [LogbookBuddyFeedPresentation.FeedTaggedBuddy],
        overflow: Int
    ) -> String {
        let names = visible.map(\.displayName)
        var label = "\(LogbookBuddyFeedPresentation.withTaggedDiversLabel) \(names.joined(separator: ", "))"
        if overflow > 0 {
            label += ", and \(overflow) more"
        }
        return label
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
    let item: FriendSharedMediaPresentation.DisplayItem
    var isPlaybackActive: Bool = false

    var body: some View {
        Group {
            if item.kind == .video {
                FriendSharedRemoteVideoPlayerView(
                    item: item,
                    isPlaybackActive: isPlaybackActive,
                    loopsPlayback: false,
                    prefersFastPlaybackStart: true
                )
            } else {
                FriendSharedMediaImageView(
                    item: item,
                    fidelity: .progressive,
                    showsVideoBadge: true
                )
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .compositingGroup()
        .clipped()
        .accessibilityLabel(
            item.kind == .video ? "Shared activity video" : "Shared activity photo"
        )
    }
}
