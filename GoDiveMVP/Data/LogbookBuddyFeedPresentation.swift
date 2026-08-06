import Foundation

/// Logbook **Buddy Feed** — merged friend-visible dive projections for the Activity Log tab.
enum LogbookBuddyFeedPresentation: Sendable {
    struct Row: Equatable, Hashable, Sendable, Identifiable {
        var id: String
        var friendUID: String
        var friendDisplayName: String
        var friendPhotoURL: String?
        var dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
        /// Whether the signed-in viewer has liked this shared activity.
        var currentUserHasLiked: Bool = false

        var likeCount: Int {
            dive.likeCount
        }

        var commentCount: Int {
            dive.commentCount
        }
    }

    /// One page in the Buddy Feed tile hero pager (featured media, depth chart / swim map, or placeholder).
    enum HeroPage: Equatable, Sendable, Identifiable {
        case media(FriendSharedMediaPresentation.DisplayItem)
        case activityVisualization
        case placeholder

        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.media(let left), .media(let right)):
                left == right
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
            case .media(let item):
                "media-\(item.mediaID)"
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

    /// Whether a push-notification deep-link target is present in the loaded feed.
    nonisolated static func containsRow(
        in rows: [Row],
        friendUID: String,
        diveDocumentID: String
    ) -> Bool {
        row(in: rows, friendUID: friendUID, diveDocumentID: diveDocumentID) != nil
    }

    nonisolated static func row(
        in rows: [Row],
        friendUID: String,
        diveDocumentID: String
    ) -> Row? {
        rows.first { $0.friendUID == friendUID && $0.dive.id == diveDocumentID }
    }

    /// Inserts or replaces a row, then re-sorts newest-first (used when a push deep-link
    /// fetches the projection directly before the full feed list includes it).
    nonisolated static func inserting(_ row: Row, into rows: [Row]) -> [Row] {
        var next = rows.filter { existing in
            existing.id != row.id
                && !(existing.friendUID == row.friendUID && existing.dive.id == row.dive.id)
        }
        next.append(row)
        return sortRowsNewestFirst(next)
    }

    /// Expands the visible page window so a deep-linked activity is not stuck behind “Load more”.
    nonisolated static func displayedCountMakingTargetVisible(
        rows: [Row],
        friendUID: String,
        diveDocumentID: String,
        currentDisplayedCount: Int
    ) -> Int {
        guard let index = rows.firstIndex(where: {
            $0.friendUID == friendUID && $0.dive.id == diveDocumentID
        }) else {
            return currentDisplayedCount
        }
        return max(currentDisplayedCount, index + 1)
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
                || left.friendPhotoURL != right.friendPhotoURL
                || left.currentUserHasLiked != right.currentUserHasLiked
                || left.dive.id != right.dive.id
                || left.dive.likeCount != right.dive.likeCount
                || left.dive.commentCount != right.dive.commentCount
                || left.dive.profileTrackBase64 != right.dive.profileTrackBase64
                || left.dive.swimTrackBase64 != right.dive.swimTrackBase64
                || left.dive.mediaItems != right.dive.mediaItems
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
                        friendPhotoURL: friend.photoURL,
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

    // MARK: - Social post chrome

    /// Apple OK-hand emoji used as a mask for the tinted like control.
    nonisolated static let likeEmoji = "👌"
    nonisolated static let likeAccessibilityLabel = "Like"
    nonisolated static let unlikeAccessibilityLabel = "Unlike"
    nonisolated static let withTaggedDiversLabel = "with"
    nonisolated static let maxVisibleTaggedBuddyAvatars = 4

    /// Compact Instagram-style relative timestamp for the post header (`5m`, `2h`, `3d`, `2w`, or abbreviated date).
    nonisolated static func postTimestampText(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        compactRelativeTimestamp(for: dive.startTime, now: now, calendar: calendar)
    }

    /// Compact relative timestamp (`5m`, `2h`, …) for comments and feed posts.
    nonisolated static func compactRelativeTimestamp(
        for date: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        guard let date else { return nil }
        let seconds = now.timeIntervalSince(date)
        if seconds < 0 {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        if seconds < 60 { return "now" }
        if seconds < 3_600 {
            return "\(Int(seconds / 60))m"
        }
        if seconds < 86_400 {
            return "\(Int(seconds / 3_600))h"
        }
        if seconds < 86_400 * 7 {
            return "\(Int(seconds / 86_400))d"
        }
        if seconds < 86_400 * 28 {
            return "\(Int(seconds / (86_400 * 7)))w"
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    /// One-line activity verb under the friend name (e.g. "logged a dive").
    nonisolated static func postActivityVerb(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String {
        switch dive.resolvedActivityKind {
        case .scubaDive:
            "logged a dive"
        case .snorkel:
            "logged a snorkel"
        }
    }

    /// Trimmed shared notes for the post caption (nil when empty / not shared).
    nonisolated static func postNotesPreview(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String? {
        guard let notes = dive.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
              !notes.isEmpty
        else { return nil }
        return notes
    }

    /// Tagged divers shown on the Buddy Feed post ("with" row).
    struct FeedTaggedBuddy: Equatable, Hashable, Sendable, Identifiable {
        var id: String
        var displayName: String
        var firebaseUID: String?
        /// Always **`false`** on Buddy Feed “with” chips (no GoDive pin).
        var showsGoDiveUserPin: Bool
    }

    /// Buddy Feed “with” avatars never show the GoDive user pin.
    nonisolated static let feedTaggedBuddyShowsGoDiveUserPin = false

    /// Overview-panel scroll target for Map **Buddies** after tapping a feed “with” avatar.
    nonisolated static let taggedBuddiesPanelScrollSectionID = "FriendSharedActivity.TaggedBuddies"

    /// Delay after push so the Map large detent mounts before scrolling to Buddies.
    nonisolated static let scrollToTaggedBuddiesAfterNavigationDelayMilliseconds = 320

    nonisolated static func shouldScrollToTaggedBuddiesOnAppear(
        scrollToTaggedBuddiesOnAppear: Bool,
        alreadyConsumed: Bool
    ) -> Bool {
        scrollToTaggedBuddiesOnAppear && !alreadyConsumed
    }

    nonisolated static func feedTaggedBuddies(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> [FeedTaggedBuddy] {
        dive.taggedBuddies.compactMap { tagged in
            let name = tagged.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let uid = tagged.firebaseUID?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedUID = (uid?.isEmpty == false) ? uid : nil
            let id = resolvedUID ?? name
            return FeedTaggedBuddy(
                id: id,
                displayName: name,
                firebaseUID: resolvedUID,
                showsGoDiveUserPin: feedTaggedBuddyShowsGoDiveUserPin
            )
        }
    }

    nonisolated static func visibleFeedTaggedBuddies(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> [FeedTaggedBuddy] {
        Array(feedTaggedBuddies(for: dive).prefix(maxVisibleTaggedBuddyAvatars))
    }

    nonisolated static func overflowTaggedBuddyCount(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> Int {
        max(0, feedTaggedBuddies(for: dive).count - maxVisibleTaggedBuddyAvatars)
    }

    /// First-name list for the "with" caption when few buddies are tagged (no overflow).
    nonisolated static func withTaggedBuddyNamesLine(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String? {
        let buddies = feedTaggedBuddies(for: dive)
        guard !buddies.isEmpty, buddies.count <= maxVisibleTaggedBuddyAvatars else { return nil }
        let names = buddies.map { DiveBuddyPresentation.firstName(from: $0.displayName) }
        switch names.count {
        case 1:
            return names[0]
        case 2:
            return "\(names[0]) & \(names[1])"
        default:
            let leading = names.dropLast().joined(separator: ", ")
            return "\(leading) & \(names[names.count - 1])"
        }
    }

    nonisolated static func likeAccessibilityLabel(isLiked: Bool) -> String {
        isLiked ? unlikeAccessibilityLabel : likeAccessibilityLabel
    }

    /// Visible like tally next to the OK-hand control (`nil` when zero and not liked by the viewer).
    nonisolated static func likeCountLabel(count: Int, isLikedByCurrentUser: Bool) -> String? {
        let safe = max(0, count)
        if safe == 0 { return isLikedByCurrentUser ? "1" : nil }
        return "\(safe)"
    }

    nonisolated static let commentAccessibilityLabel = "Comments"
    nonisolated static let commentSymbolName = "bubble.right"

    /// Visible comment tally next to the comment control (`nil` when zero).
    nonisolated static func commentCountLabel(count: Int) -> String? {
        let safe = max(0, count)
        return safe > 0 ? "\(safe)" : nil
    }

    /// Applies an optimistic comment-count delta after a successful local post (or delete).
    nonisolated static func rowApplyingCommentCountDelta(_ row: Row, delta: Int) -> Row {
        var next = row
        var dive = row.dive
        dive.commentCount = max(0, row.dive.commentCount + delta)
        next.dive = dive
        return next
    }

    /// Compact relative timestamp for a comment (`5m`, `2h`, …) — same rules as feed post times.
    nonisolated static func commentTimestampText(
        createdAt: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        compactRelativeTimestamp(for: createdAt, now: now, calendar: calendar)
    }

    /// Applies an optimistic like / unlike to a feed row (immediate tally).
    nonisolated static func rowApplyingLikeToggle(_ row: Row, liked: Bool) -> Row {
        var next = row
        next.currentUserHasLiked = liked
        var dive = row.dive
        if liked, !row.currentUserHasLiked {
            dive.likeCount = row.dive.likeCount + 1
        } else if !liked, row.currentUserHasLiked {
            dive.likeCount = max(0, row.dive.likeCount - 1)
        }
        next.dive = dive
        return next
    }

    /// Merges server-known like docs into feed rows (`likedRowIDs` = `friendUID_activityID`).
    nonisolated static func enrichingRows(
        _ rows: [Row],
        likedRowIDs: Set<String>
    ) -> [Row] {
        rows.map { row in
            var next = row
            next.currentUserHasLiked = likedRowIDs.contains(row.id)
            return next
        }
    }

    /// Replaces one row in the list after a like toggle (preserves order).
    nonisolated static func replacingRow(_ row: Row, in rows: [Row]) -> [Row] {
        rows.map { existing in
            existing.id == row.id ? row : existing
        }
    }

    /// Shared media with the owner's featured preview first when known.
    nonisolated static func orderedMediaPreviews(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> [GoDiveSharedDiveProjectionMapping.MediaPreviewSnapshot] {
        FriendSharedMediaPresentation.orderedDisplayItems(for: dive).compactMap { item in
            guard let thumb = item.thumbnailURL else { return nil }
            return GoDiveSharedDiveProjectionMapping.MediaPreviewSnapshot(
                photoID: item.mediaID,
                previewURL: thumb
            )
        }
    }

    /// Single tile hero media — the owner's featured item when known, otherwise the first shared item.
    nonisolated static func tileFeaturedDisplayItem(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> FriendSharedMediaPresentation.DisplayItem? {
        FriendSharedMediaPresentation.tileFeaturedDisplayItem(for: dive)
    }

    /// Legacy v2 preview helper — prefer **`tileFeaturedDisplayItem`**.
    nonisolated static func tileFeaturedMediaPreview(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> GoDiveSharedDiveProjectionMapping.MediaPreviewSnapshot? {
        guard let item = tileFeaturedDisplayItem(for: dive),
              let thumb = item.thumbnailURL
        else { return nil }
        return GoDiveSharedDiveProjectionMapping.MediaPreviewSnapshot(
            photoID: item.mediaID,
            previewURL: thumb
        )
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
        if let media = tileFeaturedDisplayItem(for: dive) {
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
