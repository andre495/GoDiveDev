import Foundation

/// Caps which gallery items are eligible for friend-visible shared media uploads.
enum GoDiveSharedMediaSelection: Sendable {

    struct ShareCandidate: Equatable, Sendable {
        var id: UUID
        var kind: DiveMediaKind
        var capturedAt: Date?
        var sortOrder: Int
    }

    @MainActor
    static func shareCandidate<T: ActivityOverviewGalleryMedia>(from media: T) -> ShareCandidate {
        ShareCandidate(
            id: media.id,
            kind: media.resolvedMediaKind,
            capturedAt: media.capturedAt,
            sortOrder: media.sortOrder
        )
    }

    /// Keeps gallery order; caps at **20** photos and **10** videos (earliest in sort order).
    nonisolated static func filteredForShare(candidates: [ShareCandidate]) -> [ShareCandidate] {
        var photoCount = 0
        var videoCount = 0
        var result: [ShareCandidate] = []
        result.reserveCapacity(candidates.count)

        for candidate in candidates {
            switch candidate.kind {
            case .image:
                guard photoCount < GoDiveSharedMediaLimits.maxPhotosPerActivity else { continue }
                photoCount += 1
            case .video:
                guard videoCount < GoDiveSharedMediaLimits.maxVideosPerActivity else { continue }
                videoCount += 1
            }
            result.append(candidate)
        }
        return result
    }

    @MainActor
    static func filteredForShare<T: ActivityOverviewGalleryMedia>(_ sorted: [T]) -> [T] {
        let allowedIDs = Set(filteredForShare(candidates: sorted.map(shareCandidate(from:))).map(\.id))
        return sorted.filter { allowedIDs.contains($0.id) }
    }

    /// Featured item first when it is in the capped selection (upload / Firestore ordering).
    @MainActor
    static func uploadOrder<T: ActivityOverviewGalleryMedia>(
        selected: [T],
        featuredID: UUID?
    ) -> [T] {
        guard let featuredID,
              let featured = selected.first(where: { $0.id == featuredID })
        else { return selected }
        return [featured] + selected.filter { $0.id != featuredID }
    }

    struct CapTrimSummary: Equatable, Sendable {
        var droppedPhotoCount: Int
        var droppedVideoCount: Int

        nonisolated var wasTrimmed: Bool {
            droppedPhotoCount > 0 || droppedVideoCount > 0
        }
    }

    nonisolated static func capTrimSummary(
        candidates: [ShareCandidate],
        shared: [ShareCandidate]
    ) -> CapTrimSummary {
        let totalPhotos = candidates.filter { $0.kind == .image }.count
        let totalVideos = candidates.filter { $0.kind == .video }.count
        let sharedPhotos = shared.filter { $0.kind == .image }.count
        let sharedVideos = shared.filter { $0.kind == .video }.count
        return CapTrimSummary(
            droppedPhotoCount: max(0, totalPhotos - sharedPhotos),
            droppedVideoCount: max(0, totalVideos - sharedVideos)
        )
    }

    /// User-facing copy when per-activity caps removed items from the upload set.
    nonisolated static func trimNoticeMessage(_ summary: CapTrimSummary) -> String? {
        guard summary.wasTrimmed else { return nil }
        var parts: [String] = []
        if summary.droppedPhotoCount > 0 {
            parts.append(
                "\(summary.droppedPhotoCount) photo\(summary.droppedPhotoCount == 1 ? "" : "s")"
            )
        }
        if summary.droppedVideoCount > 0 {
            parts.append(
                "\(summary.droppedVideoCount) video\(summary.droppedVideoCount == 1 ? "" : "s")"
            )
        }
        let joined = parts.joined(separator: " and ")
        return "Only the first \(GoDiveSharedMediaLimits.maxPhotosPerActivity) photos and \(GoDiveSharedMediaLimits.maxVideosPerActivity) videos are shared with friends. \(joined) on this activity were not uploaded."
    }

    /// **`true`** when **`filtered`** preserves the relative order of **`candidates`**.
    nonisolated static func preservesGalleryOrder(
        candidates: [ShareCandidate],
        filtered: [ShareCandidate]
    ) -> Bool {
        var searchIndex = candidates.startIndex
        for item in filtered {
            guard let matchIndex = candidates[searchIndex...].firstIndex(where: { $0.id == item.id }) else {
                return false
            }
            searchIndex = candidates.index(after: matchIndex)
        }
        return true
    }
}
