import Foundation

/// Logbook **Buddy Feed** — merged friend-visible dive projections for the Activity Log tab.
enum LogbookBuddyFeedPresentation: Sendable {
    struct Row: Equatable, Sendable, Identifiable {
        var id: String
        var friendUID: String
        var friendDisplayName: String
        var dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    }

    /// One page in the Buddy Feed tile hero pager (featured media, depth chart / swim map, or placeholder).
    enum HeroPage: Equatable, Sendable, Identifiable {
        case media(GoDiveSharedDiveProjectionMapping.MediaPreviewSnapshot)
        case activityVisualization
        case placeholder

        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.media(let left), .media(let right)):
                left.photoID == right.photoID && left.previewURL == right.previewURL
            case (.activityVisualization, .activityVisualization):
                true
            case (.placeholder, .placeholder):
                true
            default:
                false
            }
        }

        var id: String {
            switch self {
            case .media(let preview):
                "media-\(preview.photoID)"
            case .activityVisualization:
                "activity"
            case .placeholder:
                "placeholder"
            }
        }
    }

    nonisolated static let loadMoreAccessibilityIdentifier = "Logbook.BuddyFeed.LoadMore"

    nonisolated static let pageSize = 20

    /// Visible buddy-feed slice after pagination.
    nonisolated static func visibleRows(
        from allRows: [Row],
        displayedCount: Int
    ) -> [Row] {
        guard displayedCount > 0 else { return [] }
        return Array(allRows.prefix(displayedCount))
    }

    nonisolated static func initialDisplayedCount(for totalRowCount: Int) -> Int {
        min(pageSize, max(totalRowCount, 0))
    }

    nonisolated static func hasMoreRows(totalRowCount: Int, displayedCount: Int) -> Bool {
        displayedCount < totalRowCount
    }

    nonisolated static func nextDisplayedCount(current: Int, totalRowCount: Int) -> Int {
        min(current + pageSize, totalRowCount)
    }

    nonisolated static func shouldLoadNextPage(
        rowIndex: Int,
        visibleRowCount: Int,
        totalRowCount: Int,
        displayedCount: Int
    ) -> Bool {
        guard hasMoreRows(totalRowCount: totalRowCount, displayedCount: displayedCount) else {
            return false
        }
        guard visibleRowCount > 0 else { return false }
        return rowIndex >= visibleRowCount - 1
    }

    enum EmptyKind: Equatable, Sendable {
        case noFriends
        case noSharedDives
        case unavailable
    }

    nonisolated static let scopePickerAccessibilityIdentifier = "Logbook.FeedScopePicker"
    nonisolated static let buddyFeedRootAccessibilityIdentifier = "Logbook.BuddyFeed.Root"

    nonisolated static let noFriendsTitle = "No friends yet"
    nonisolated static let noFriendsMessage =
        "When friends share dives and snorkels with you, their activities show up here. Invite someone to get started."

    nonisolated static let noActivitiesTitle = "No buddy activities yet"
    nonisolated static let noActivitiesMessage =
        "None of your friends have shared activities yet. Check back later, or invite more divers from Friends."

    nonisolated static let unavailableTitle = "Can't load buddy feed"

    nonisolated static let addFriendsButtonTitle = "Add friends"
    nonisolated static let viewFriendsButtonTitle = "View friends"
    nonisolated static let openFriendsButtonAccessibilityIdentifier = "Logbook.BuddyFeed.OpenFriends"

    nonisolated static func openFriendsButtonTitle(for kind: EmptyKind) -> String? {
        switch kind {
        case .noFriends:
            addFriendsButtonTitle
        case .noSharedDives:
            viewFriendsButtonTitle
        case .unavailable:
            nil
        }
    }

    nonisolated static func showsOpenFriendsButton(for kind: EmptyKind) -> Bool {
        openFriendsButtonTitle(for: kind) != nil
    }

    nonisolated static func rowsEqual(_ lhs: [Row], _ rhs: [Row]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for index in lhs.indices {
            let left = lhs[index]
            let right = rhs[index]
            if left.id != right.id
                || left.friendUID != right.friendUID
                || left.friendDisplayName != right.friendDisplayName
                || left.dive.id != right.dive.id
                || left.dive.profileTrackBase64 != right.dive.profileTrackBase64
                || left.dive.swimTrackBase64 != right.dive.swimTrackBase64
                || left.dive.mediaPreviews != right.dive.mediaPreviews
                || left.dive.featuredMediaPhotoID != right.dive.featuredMediaPhotoID
            {
                return false
            }
        }
        return true
    }

    nonisolated static func emptyKindsEqual(_ lhs: EmptyKind?, _ rhs: EmptyKind?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case (.noFriends?, .noFriends?),
             (.noSharedDives?, .noSharedDives?),
             (.unavailable?, .unavailable?):
            return true
        default:
            return false
        }
    }

    nonisolated static func rowID(friendUID: String, diveDocumentID: String) -> String {
        "\(friendUID)_\(diveDocumentID)"
    }

    nonisolated static func rows(
        friends: [GoDiveFriendGraphService.FriendEdge],
        divesByFriendUID: [String: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive]]
    ) -> [Row] {
        var merged: [Row] = []
        merged.reserveCapacity(divesByFriendUID.values.reduce(0) { $0 + $1.count })
        for friend in friends {
            let dives = divesByFriendUID[friend.friendUID] ?? []
            for dive in dives {
                merged.append(
                    Row(
                        id: rowID(friendUID: friend.friendUID, diveDocumentID: dive.id),
                        friendUID: friend.friendUID,
                        friendDisplayName: friend.displayName,
                        dive: dive
                    )
                )
            }
        }
        return sortRowsNewestFirst(merged)
    }

    /// Newest activity first — **`startTime`**, then **`diveNumber`**, then stable id.
    nonisolated static func sortFriendVisibleDivesNewestFirst(
        _ dives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive]
    ) -> [GoDiveSharedDiveProjectionMapping.FriendVisibleDive] {
        dives.sorted(by: friendVisibleDiveIsNewerFirst)
    }

    nonisolated static func sortRowsNewestFirst(_ rows: [Row]) -> [Row] {
        rows.sorted { lhs, rhs in
            if friendVisibleDiveIsNewerFirst(lhs.dive, rhs.dive) { return true }
            if friendVisibleDiveIsNewerFirst(rhs.dive, lhs.dive) { return false }
            return lhs.id < rhs.id
        }
    }

    nonisolated static func friendVisibleDiveIsNewerFirst(
        _ lhs: GoDiveSharedDiveProjectionMapping.FriendVisibleDive,
        _ rhs: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> Bool {
        let left = chronologicalSortKey(for: lhs)
        let right = chronologicalSortKey(for: rhs)
        if left.instant != right.instant { return left.instant > right.instant }
        if left.diveNumber != right.diveNumber {
            return (left.diveNumber ?? Int.min) > (right.diveNumber ?? Int.min)
        }
        return lhs.id < rhs.id
    }

    nonisolated static func chronologicalSortKey(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> (instant: Date, diveNumber: Int?) {
        (
            instant: dive.startTime ?? dive.updatedAt ?? .distantPast,
            diveNumber: dive.diveNumber
        )
    }

    nonisolated static func subtitle(for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive) -> String {
        tileStatsLine(for: dive, unitSystem: .metric)
    }

    nonisolated static func tileStatsLine(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive,
        unitSystem: DiveDisplayUnitSystem
    ) -> String {
        switch dive.resolvedActivityKind {
        case .scubaDive:
            var parts: [String] = []
            if let number = dive.diveNumber {
                parts.append("#\(number)")
            }
            if let start = dive.startTime {
                parts.append(start.formatted(date: .abbreviated, time: .omitted))
            }
            if let max = dive.maxDepthMeters {
                parts.append(DiveQuantityFormatting.depth(meters: max, system: unitSystem))
            }
            if let minutes = dive.durationMinutes {
                parts.append("\(minutes) min")
            }
            return parts.joined(separator: " · ")
        case .snorkel:
            var parts: [String] = []
            if let start = dive.startTime {
                parts.append(start.formatted(date: .abbreviated, time: .omitted))
            }
            if let minutes = dive.durationMinutes {
                parts.append("\(minutes) min")
            }
            if let distance = dive.swimDistanceMeters {
                parts.append(DiveQuantityFormatting.swimDistance(meters: distance, system: unitSystem))
            }
            return parts.joined(separator: " · ")
        }
    }

    nonisolated static func tileSiteTitle(for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive) -> String {
        GoDiveSharedDiveProjectionMapping.displayTitle(for: dive)
    }

    nonisolated static func tileRegionCountryLine(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String? {
        GoDiveSharedDiveProjectionMapping.regionCountryDisplayLine(for: dive)
    }

    /// Shared media with the owner's featured preview first when known.
    nonisolated static func orderedMediaPreviews(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> [GoDiveSharedDiveProjectionMapping.MediaPreviewSnapshot] {
        let previews = dive.mediaPreviews
        guard !previews.isEmpty else { return [] }
        guard let featuredID = dive.featuredMediaPhotoID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !featuredID.isEmpty,
              let featuredIndex = previews.firstIndex(where: { $0.photoID == featuredID })
        else { return previews }

        var ordered = previews
        let featured = ordered.remove(at: featuredIndex)
        ordered.insert(featured, at: 0)
        return ordered
    }

    /// Single tile hero media — the owner's featured preview when known, otherwise the first shared preview.
    nonisolated static func tileFeaturedMediaPreview(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> GoDiveSharedDiveProjectionMapping.MediaPreviewSnapshot? {
        orderedMediaPreviews(for: dive).first
    }

    /// **`true`** when the tile can show a depth chart (dives) or swim map (snorkels).
    nonisolated static func hasSharedActivityVisualization(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> Bool {
        switch dive.resolvedActivityKind {
        case .scubaDive:
            return GoDiveSharedDiveProjectionMapping
                .decodedDepthChartSeries(from: dive)
                .hasRenderableProfile
        case .snorkel:
            let coordinates = GoDiveSharedDiveProjectionMapping.decodedSwimTrackCoordinates(from: dive)
            if coordinates.count >= 2 { return true }
            guard let latitude = dive.entryLatitude,
                  let longitude = dive.entryLongitude
            else { return false }
            let coordinate = DiveCoordinate(latitude: latitude, longitude: longitude)
            return DiveMapCoordinateResolver.isUsable(coordinate)
        }
    }

    /// Hero pager pages: at most one media page + one visualization, or a placeholder when neither exists.
    nonisolated static func heroPages(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> [HeroPage] {
        var pages: [HeroPage] = []
        if let media = tileFeaturedMediaPreview(for: dive) {
            pages.append(.media(media))
        }
        if hasSharedActivityVisualization(for: dive) {
            pages.append(.activityVisualization)
        }
        if pages.isEmpty {
            pages.append(.placeholder)
        }
        return pages
    }

    nonisolated static func showsHeroPager(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> Bool {
        heroPages(for: dive).count > 1
    }

    nonisolated static func emptyKind(
        friends: [GoDiveFriendGraphService.FriendEdge],
        rows: [Row],
        firebaseConfigured: Bool,
        isSignedIn: Bool
    ) -> EmptyKind? {
        guard firebaseConfigured, isSignedIn else { return .unavailable }
        if friends.isEmpty { return .noFriends }
        if rows.isEmpty { return .noSharedDives }
        return nil
    }

    /// Buddy Feed auto-refresh when the list is visible (logbook stack at root + **Buddy Feed** segment + Logbook tab selected).
    nonisolated static func shouldAutoRefreshBuddyFeedList(
        feedScope: LogbookFeedScope,
        navigationPathCount: Int,
        isLogbookTabSelected: Bool
    ) -> Bool {
        isLogbookTabSelected
            && feedScope == .buddyFeed
            && navigationPathCount == 0
    }
}
