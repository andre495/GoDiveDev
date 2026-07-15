import Foundation

/// Serializes PhotoKit library video requests so Home carousel warm + resolve do not starve each other.
///
/// Concurrent **`requestPlayerItem`** / **`requestAVAsset`** for multiple iCloud clips routinely times out
/// (~30 s each) while soft posters remain on screen.
@MainActor
enum DiveMediaVideoPhotoKitGate {
    private static var isBusy = false
    private static var waiters: [CheckedContinuation<Void, Never>] = []

    /// Max concurrent library video PhotoKit requests (playback streaming is heavy on iCloud).
    nonisolated static let maxConcurrentRequests = 1

    static func withExclusiveAccess<T>(
        _ operation: () async -> T
    ) async -> T {
        await acquire()
        defer { release() }
        return await operation()
    }

    private static func acquire() async {
        if !isBusy {
            isBusy = true
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiters.append(continuation)
        }
    }

    private static func release() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else if isBusy {
            isBusy = false
        }
    }
}

/// Testable policy for serial Home video warm order + active-only ensure.
enum DiveMediaVideoPhotoKitGatePresentation: Sendable {
    nonisolated static func prioritizedVideoMediaIDs(
        mediaIDs: [UUID],
        priorityMediaID: UUID?
    ) -> [UUID] {
        guard let priorityMediaID,
              let index = mediaIDs.firstIndex(of: priorityMediaID) else {
            return mediaIDs
        }
        var ordered = mediaIDs
        ordered.swapAt(0, index)
        return ordered
    }

    nonisolated static func prioritizedVideoMedia(
        _ mediaRows: [DiveMediaPhoto],
        priorityMediaID: UUID?
    ) -> [DiveMediaPhoto] {
        let videos = mediaRows.filter { $0.resolvedMediaKind == .video }
        let orderedIDs = prioritizedVideoMediaIDs(
            mediaIDs: videos.map(\.id),
            priorityMediaID: priorityMediaID
        )
        let byID = Dictionary(uniqueKeysWithValues: videos.map { ($0.id, $0) })
        return orderedIDs.compactMap { byID[$0] }
    }

    /// Active clip may always prepare; the **forward** neighbor prefeches for swipe.
    ///
    /// With **3** slides, wrapping “previous” of index **0** made **every** slide prepare at once and
    /// starved the first item’s **`requestPlayerItem`**.
    nonisolated static func shouldEnsureCarouselVideoReady(
        isSlidePlaybackActive: Bool,
        isAdjacentToActive: Bool = false
    ) -> Bool {
        isSlidePlaybackActive || isAdjacentToActive
    }

    /// Whether a carousel page should kick **`requestPlayerItem`** for its video.
    /// Uses the selected logical index even before the carousel is on-screen / playback-allowed.
    nonisolated static func shouldPrepareCarouselVideo(
        logicalIndex: Int,
        activeLogicalIndex: Int,
        slideCount: Int
    ) -> Bool {
        guard slideCount > 0 else { return false }
        if logicalIndex == activeLogicalIndex { return true }
        guard slideCount > 1 else { return false }
        let next = (activeLogicalIndex + 1) % slideCount
        return logicalIndex == next
    }

    /// Indices adjacent to the visible logical slide (wraps) — kept for tests / diagnostics.
    nonisolated static func adjacentLogicalIndices(
        activeLogicalIndex: Int,
        slideCount: Int
    ) -> [Int] {
        guard slideCount > 1 else { return [] }
        let previous = (activeLogicalIndex - 1 + slideCount) % slideCount
        let next = (activeLogicalIndex + 1) % slideCount
        if previous == next { return [previous] }
        return [previous, next]
    }
}
