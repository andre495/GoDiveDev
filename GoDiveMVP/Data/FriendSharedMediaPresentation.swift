import Foundation

/// Friend-visible shared media — v3 **`mediaItems`** with v2 **`mediaPreviews`** fallback.
enum FriendSharedMediaPresentation: Sendable {

    struct DisplayItem: Sendable, Identifiable {
        var mediaID: String
        var kind: FriendSharedMediaKind
        var thumbnailURL: String?
        var contentURL: String?

        var id: String { mediaID }
    }

    nonisolated static func sanitizedThumbnailURL(from raw: String?) -> URL? {
        guard let raw else { return nil }
        return GoDiveRemoteURLPolicy.sanitizedFirebaseStorageURL(from: raw)
    }

    nonisolated static func sanitizedContentURL(from raw: String?) -> URL? {
        guard let raw else { return nil }
        return GoDiveRemoteURLPolicy.sanitizedFirebaseStorageURL(from: raw)
    }

    nonisolated static func displayItems(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> [DisplayItem] {
        if !dive.mediaItems.isEmpty {
            return dive.mediaItems.map(displayItem(from:))
        }
        return dive.mediaPreviews.map {
            DisplayItem(
                mediaID: $0.photoID,
                kind: .photo,
                thumbnailURL: $0.previewURL,
                contentURL: nil
            )
        }
    }

    nonisolated static func orderedDisplayItems(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> [DisplayItem] {
        let items = displayItems(for: dive)
        guard !items.isEmpty else { return [] }
        guard let featuredID = dive.featuredMediaPhotoID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !featuredID.isEmpty,
              let featuredIndex = items.firstIndex(where: { $0.mediaID == featuredID })
        else { return items }

        var ordered = items
        let featured = ordered.remove(at: featuredIndex)
        ordered.insert(featured, at: 0)
        return ordered
    }

    nonisolated static func tileFeaturedDisplayItem(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> DisplayItem? {
        orderedDisplayItems(for: dive).first
    }

    nonisolated static func hasSharedMedia(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> Bool {
        !displayItems(for: dive).isEmpty
    }

    /// Next **`count`** buddy-feed thumbnail URLs after **`startIndex`** (inclusive).
    nonisolated static func buddyFeedThumbnailPrefetchURLs(
        rows: [LogbookBuddyFeedPresentation.Row],
        startIndex: Int,
        count: Int = 3
    ) -> [String] {
        guard count > 0, startIndex >= 0, startIndex < rows.count else { return [] }
        let end = min(rows.count, startIndex + count)
        var urls: [String] = []
        urls.reserveCapacity(count)
        for index in startIndex ..< end {
            guard let thumb = tileFeaturedDisplayItem(for: rows[index].dive)?.thumbnailURL,
                  sanitizedThumbnailURL(from: thumb) != nil
            else { continue }
            urls.append(thumb)
        }
        return urls
    }

    nonisolated static func detailThumbnailPrefetchURLs(
        items: [DisplayItem],
        limit: Int = 6
    ) -> [String] {
        items.prefix(limit).compactMap { item in
            guard let thumb = item.thumbnailURL,
                  sanitizedThumbnailURL(from: thumb) != nil
            else { return nil }
            return thumb
        }
    }

    /// Featured + adjacent item content URLs for detail open / pager prefetch.
    nonisolated static func detailContentPrefetchURLs(
        items: [DisplayItem],
        selectedMediaID: String?,
        radius: Int = 1
    ) -> [String] {
        guard !items.isEmpty else { return [] }
        let anchorID = selectedMediaID ?? items[0].mediaID
        guard let anchorIndex = items.firstIndex(where: { $0.mediaID == anchorID }) else { return [] }
        let lower = max(0, anchorIndex - radius)
        let upper = min(items.count - 1, anchorIndex + radius)
        var urls: [String] = []
        for index in lower ... upper {
            guard let content = items[index].contentURL,
                  sanitizedContentURL(from: content) != nil
            else { continue }
            urls.append(content)
        }
        return urls
    }

    /// All shared video **`contentURL`** values for an activity (detail open prefetch).
    nonisolated static func allVideoContentPrefetchURLs(items: [DisplayItem]) -> [String] {
        items.compactMap { item in
            guard item.kind == .video,
                  let content = item.contentURL,
                  sanitizedContentURL(from: content) != nil
            else { return nil }
            return content
        }
    }

    /// All shared photo **`contentURL`** values for an activity (detail open prefetch).
    nonisolated static func allPhotoContentPrefetchURLs(items: [DisplayItem]) -> [String] {
        items.compactMap { item in
            guard item.kind == .photo,
                  let content = item.contentURL,
                  sanitizedContentURL(from: content) != nil
            else { return nil }
            return content
        }
    }

    /// Buddy Feed tile featured still **`contentURL`** when the hero item is a photo.
    nonisolated static func buddyFeedFeaturedPhotoContentPrefetchURL(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String? {
        guard let item = tileFeaturedDisplayItem(for: dive),
              item.kind == .photo,
              let content = item.contentURL,
              sanitizedContentURL(from: content) != nil
        else { return nil }
        return content
    }

    /// Buddy Feed tile featured video content URL when the hero item is a clip.
    nonisolated static func buddyFeedFeaturedVideoContentPrefetchURL(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String? {
        guard let item = tileFeaturedDisplayItem(for: dive),
              item.kind == .video,
              let content = item.contentURL,
              sanitizedContentURL(from: content) != nil
        else { return nil }
        return content
    }

    @MainActor
    static func prefetchContentIfAllowed(urls: [String]) async {
        let unique = Array(Set(urls))
        guard !unique.isEmpty else { return }
        let snapshot = AppNetworkConnectivitySnapshot.shared
        let allowsContent = allowsContentDownload(
            isConnected: snapshot.allowsCloudMediaFetch,
            usesWiFi: snapshot.usesWiFiInterface,
            wifiOnly: AppUserSettings.downloadFriendMediaOnWiFiOnly(),
            allowsConstrainedNetworkAccess: URLSession.shared.configuration.allowsConstrainedNetworkAccess
        )
        guard allowsContent else { return }
        await GoDiveSharedMediaCache.shared.prefetch(
            remoteURLStrings: unique,
            tier: .content,
            allowsNetworkFetch: true
        )
    }

    @MainActor
    static func prefetchVideoContentIfAllowed(urls: [String]) async {
        await prefetchContentIfAllowed(urls: urls)
    }

    /// Cache-first playback URL for shared video **`contentURL`** strings.
    @MainActor
    static func resolvedVideoPlaybackURL(for contentURLString: String?) async -> URL? {
        guard let contentURLString,
              sanitizedContentURL(from: contentURLString) != nil
        else { return nil }
        return await GoDiveSharedMediaCache.shared.resolvedPlaybackURL(
            remoteURLString: contentURLString,
            tier: .content
        )
    }

    @MainActor
    static func prefetchVideoContentIfNeeded(
        contentURLString: String?,
        allowsNetworkFetch: Bool
    ) async {
        guard allowsNetworkFetch,
              let contentURLString,
              sanitizedContentURL(from: contentURLString) != nil
        else { return }
        await GoDiveSharedMediaCache.shared.prefetch(
            remoteURLStrings: [contentURLString],
            tier: .content,
            allowsNetworkFetch: true,
            maxConcurrent: 1
        )
    }

    nonisolated static func allowsContentDownload(
        isConnected: Bool,
        usesWiFi: Bool,
        wifiOnly: Bool,
        allowsConstrainedNetworkAccess: Bool
    ) -> Bool {
        guard isConnected else { return false }
        guard allowsConstrainedNetworkAccess else { return false }
        guard !wifiOnly || usesWiFi else { return false }
        return true
    }

    nonisolated static func resolvedFeaturedMediaID(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String? {
        let trimmed = dive.featuredMediaPhotoID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        let items = displayItems(for: dive)
        guard items.contains(where: { $0.mediaID == trimmed }) else { return nil }
        return trimmed
    }

    nonisolated static func resolvedSelectedMediaID(
        selectedID: String?,
        in items: [DisplayItem],
        preferredID: String? = nil
    ) -> String? {
        guard !items.isEmpty else { return nil }
        if let selectedID,
           items.contains(where: { $0.mediaID == selectedID }) {
            return selectedID
        }
        if let preferredID,
           items.contains(where: { $0.mediaID == preferredID }) {
            return preferredID
        }
        return items.first?.mediaID
    }

    nonisolated private static func displayItem(
        from item: GoDiveSharedDiveProjectionMapping.MediaItemSnapshot
    ) -> DisplayItem {
        DisplayItem(
            mediaID: item.mediaID,
            kind: item.kind,
            thumbnailURL: item.thumbnailURL,
            contentURL: item.contentURL
        )
    }
}

extension FriendSharedMediaPresentation.DisplayItem: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.mediaID == rhs.mediaID
            && lhs.kind == rhs.kind
            && lhs.thumbnailURL == rhs.thumbnailURL
            && lhs.contentURL == rhs.contentURL
    }
}
