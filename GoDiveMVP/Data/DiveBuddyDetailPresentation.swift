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
}

/// Compact media / map toggle on blue-sheet pushed heroes (buddy, trip, species, dive site).
enum PushedDetailHeroModeTogglePresentation: Sendable {
    nonisolated static let segmentSize: CGFloat = AppToolbarIconButtonMetrics.tapDimension
    nonisolated static let segmentSpacing: CGFloat = 4
    nonisolated static let shellPadding: CGFloat = 4
    nonisolated static let shellCornerRadius: CGFloat = 12
    nonisolated static let segmentCornerRadius: CGFloat = 10

    /// Intrinsic width — icon-only segments, not full-bleed **`UISegmentedControl`**.
    nonisolated static var chromeWidth: CGFloat {
        shellPadding * 2
            + segmentSize * 2
            + segmentSpacing
    }
}

extension DiveBuddyDetailPresentation {

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

    /// Dive ids for tagged-media resolution — shared dives + tagged dives only (not the full owner logbook).
    nonisolated static func mediaScopeDiveActivityIDs(
        sharedDiveActivities: [DiveActivity],
        mediaTags: [DiveMediaBuddyTag]
    ) -> Set<UUID> {
        var ids = Set(sharedDiveActivities.map(\.id))
        for tag in mediaTags {
            if let activityID = tag.diveActivityID {
                ids.insert(activityID)
            }
        }
        return ids
    }

    nonisolated static func catalogSitesFromSharedDives(_ sharedDives: [DiveActivity]) -> [DiveSite] {
        var byID: [UUID: DiveSite] = [:]
        for dive in sharedDives {
            if let site = dive.diveSite {
                byID[site.id] = site
            }
        }
        return Array(byID.values)
    }

    nonisolated static func initialMapPins(from sharedDives: [DiveActivity]) -> [TripDetailMapPin] {
        DiveBuddyDetailMapPresentation.pins(
            from: sharedDives,
            catalogSites: catalogSitesFromSharedDives(sharedDives)
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

    nonisolated static func ownerDiveIndex(from activities: [DiveActivity]) -> OwnerDiveIndex {
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
        return ownerDiveIndex(from: activities)
    }

    nonisolated static func fetchOwnerDiveIndex(
        ownerProfileID: UUID,
        container: ModelContainer
    ) async -> OwnerDiveIndex {
        await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<DiveActivity>(
                predicate: #Predicate { $0.ownerProfileID == ownerProfileID },
                sortBy: [
                    SortDescriptor(\.startTime, order: .reverse),
                    SortDescriptor(\.id, order: .forward),
                ]
            )
            let activities = (try? context.fetch(descriptor)) ?? []
            return ownerDiveIndex(from: activities)
        }.value
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

    nonisolated static func fetchOwnerTripPersistentIDs(
        ownerProfileID: UUID,
        container: ModelContainer
    ) async -> [PersistentIdentifier] {
        await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<DiveTrip>(
                predicate: #Predicate { $0.ownerProfileID == ownerProfileID },
                sortBy: [
                    SortDescriptor(\.startDate, order: .reverse),
                    SortDescriptor(\.createdAt, order: .reverse),
                ]
            )
            let rows = (try? context.fetch(descriptor)) ?? []
            return rows.map(\.persistentModelID)
        }.value
    }

    @MainActor
    static func bindTrips(
        persistentIDs: [PersistentIdentifier],
        modelContext: ModelContext
    ) -> [DiveTrip] {
        persistentIDs.compactMap { modelContext.model(for: $0) as? DiveTrip }
    }

    @MainActor
    static func fetchOwnerTripsAsync(
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) async -> [DiveTrip] {
        let persistentIDs = await fetchOwnerTripPersistentIDs(
            ownerProfileID: ownerProfileID,
            container: modelContext.container
        )
        guard !Task.isCancelled else { return [] }
        return bindTrips(persistentIDs: persistentIDs, modelContext: modelContext)
    }
}
