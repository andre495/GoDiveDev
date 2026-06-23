import CoreGraphics
import Foundation
import SwiftData

/// Buddy detail hero chrome — tagged-media banner and overlapping profile avatar layout.
enum DiveBuddyDetailPresentation: Sendable {

    /// Hero/sheet seam — same default band as **`HomeOverviewLayout.heroLayoutStatsPanelContentHeight`**.
    nonisolated static let heroLayoutStatsPanelContentHeight: CGFloat =
        HomeOverviewLayout.heroLayoutStatsPanelContentHeight

    /// Deprecated alias — use **`heroLayoutStatsPanelContentHeight`**.
    nonisolated static let minimumPanelContentHeight: CGFloat = heroLayoutStatsPanelContentHeight

    nonisolated static let profileAvatarDiameter: CGFloat = 120
    nonisolated static let contactBadgeDiameter: CGFloat = 34

    /// Same hero height as Home tab stats overlap seam (**`LogOverviewView.homeOverviewLayoutMetrics`**).
    nonisolated static func heroHeight(
        viewportHeight: CGFloat,
        screenWidth: CGFloat,
        topSafeAreaInset: CGFloat,
        statsPanelContentHeight: CGFloat = heroLayoutStatsPanelContentHeight,
        showsBuddyLeaderboard: Bool = false,
        transitionViewportFloor: CGFloat = 0
    ) -> CGFloat {
        HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: viewportHeight,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: statsPanelContentHeight,
            showsBuddyLeaderboard: showsBuddyLeaderboard,
            transitionViewportFloor: transitionViewportFloor
        ).heroHeight
    }

    /// Pulls the avatar upward so half sits on the hero and half sits below it.
    nonisolated static func avatarOverlapOffset(diameter: CGFloat = profileAvatarDiameter) -> CGFloat {
        diameter / 2
    }

    /// Leading inset for the overlapping avatar — matches **`HomeLifetimeStatsPanel`** horizontal padding.
    nonisolated static let avatarLeadingInset: CGFloat = AppTheme.Spacing.lg

    /// Lifts buddy name + dives-together beside the overlapping avatar (applied as negative Y offset).
    nonisolated static let identityTextLift: CGFloat = 12

    /// Bottom padding for hero media/map toggle — clears **`HomeLifetimeStatsPanel`** overlap.
    nonisolated static let heroModeToggleBottomPadding: CGFloat =
        HomeLifetimeStatsLayout.panelOverlap + AppTheme.Spacing.md

    /// Picks one tagged photo/video for the hero banner (**`nil`** when the buddy has no tagged media).
    nonisolated static func randomHeroTaggedMedia(from photos: [DiveMediaPhoto]) -> DiveMediaPhoto? {
        photos.randomElement()
    }

    /// Buddy hero + tagged-media preview auto-play when the selected row is a video.
    nonisolated static func shouldAutoPlaySelectedVideo(for media: DiveMediaPhoto?) -> Bool {
        media?.resolvedMediaKind == .video
    }

    /// Prefer live **`@Query`** rows; fall back to the pushed **`DiveBuddy`** relationship on the first frame.
    nonisolated static func effectiveDiveTags(
        queried: [DiveBuddyTag],
        relationship: [DiveBuddyTag]
    ) -> [DiveBuddyTag] {
        queried.isEmpty ? relationship : queried
    }

    /// Prefer live **`@Query`** rows; fall back to the pushed **`DiveBuddy`** relationship on the first frame.
    nonisolated static func effectiveMediaTags(
        queried: [DiveMediaBuddyTag],
        relationship: [DiveMediaBuddyTag]
    ) -> [DiveMediaBuddyTag] {
        queried.isEmpty ? relationship : queried
    }

    /// Latch pushed layout floors from the last settled Home root so buddy detail does not re-layout on push.
    @MainActor
    static func initialPushedLayoutSafeAreaTopFloor() -> CGFloat {
        guard let root = HomeOverviewLayoutAnchor.root else {
            return AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(0)
        }
        return AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(root.topSafeAreaInset)
    }

    nonisolated static func initialPushedLayoutViewportFloor() -> CGFloat {
        HomeOverviewLayoutAnchor.root?.homeTabViewportHeight ?? 0
    }

    /// Hero pick from relationship tags available before **`@Query`** hydration finishes.
    @MainActor
    static func initialHeroTaggedMediaPhotoID(for buddy: DiveBuddy) -> UUID? {
        let tags = effectiveMediaTags(
            queried: [],
            relationship: Array(buddy.mediaBuddyTags)
        )
        let photos = DiveBuddyTaggedMediaPresentation.photosAvailableFromTagRelationships(tags)
        return DiveBuddyTaggedMediaPresentation.resolvedHeroMediaPhotoID(
            in: photos,
            explicitFeaturedID: buddy.featuredTaggedMediaPhotoID,
            sessionRandomID: DiveBuddyHeroMediaSession.resolvedRandomHeroMediaID(
                buddyID: buddy.id,
                in: photos
            )
        )
    }

    /// Fast first-frame dive list from pushed **`DiveBuddy`** relationships (logbook **#** refresh follows).
    @MainActor
    static func initialSharedDiveContent(
        for buddy: DiveBuddy
    ) -> (rows: [DiveLogbookRowDisplayData], sharedDives: [DiveActivity]) {
        guard let ownerProfileID = buddy.ownerProfileID else { return ([], []) }
        let sharedDives = DiveBuddyRosterPresentation.sharedDiveActivities(
            for: buddy,
            ownerProfileID: ownerProfileID
        )
        let rows = DiveBuddyRosterPresentation.sharedDiveRowDisplayData(
            sharedDives: sharedDives,
            unitSystem: AppUserSettings.diveDisplayUnitSystem(),
            useChronologicalNumbers: false
        )
        return (rows, sharedDives)
    }

    nonisolated static func fetchOwnerNumberingRows(
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> [DiveActivityDiveNumbering.NumberingRow] {
        fetchOwnerDiveIndex(ownerProfileID: ownerProfileID, modelContext: modelContext).numberingRows
    }

    struct OwnerDiveIndex: Sendable {
        let numberingRows: [DiveActivityDiveNumbering.NumberingRow]
        let timeZoneOffsetByActivityID: [UUID: Int?]
    }

    nonisolated static func fetchOwnerDiveIndex(
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> OwnerDiveIndex {
        let descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate { $0.ownerProfileID == ownerProfileID },
            sortBy: [
                SortDescriptor(\.startTime, order: .reverse),
                SortDescriptor(\.id, order: .forward),
            ]
        )
        let activities = (try? modelContext.fetch(descriptor)) ?? []
        let numberingRows = activities.map {
            DiveActivityDiveNumbering.NumberingRow(
                id: $0.id,
                startTime: $0.startTime,
                diveNumberExplicitlyNone: $0.diveNumberExplicitlyNone
            )
        }
        let timeZoneOffsetByActivityID = Dictionary(
            uniqueKeysWithValues: activities.map { ($0.id, $0.timeZoneOffsetSeconds) }
        )
        return OwnerDiveIndex(
            numberingRows: numberingRows,
            timeZoneOffsetByActivityID: timeZoneOffsetByActivityID
        )
    }

    nonisolated static func fetchOwnerTrips(
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> [DiveTrip] {
        let descriptor = FetchDescriptor<DiveTrip>(
            predicate: #Predicate { $0.ownerProfileID == ownerProfileID },
            sortBy: [
                SortDescriptor(\.startDate, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse),
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
