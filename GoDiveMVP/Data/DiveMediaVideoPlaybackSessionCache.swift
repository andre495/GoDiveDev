import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Session-scoped reuse of in-flight dive hero **`AVPlayer`** instances across SwiftUI relayout (e.g. rotation).
///
/// Each visible **`DiveActivityFillVideoPlayerUIView`** still owns layer wiring; detach stores the player here so
/// a remounted representable can resume the same stream at the current time. Cleared when app backgrounds.
@MainActor
final class DiveMediaVideoPlaybackSessionCache {
    static let shared = DiveMediaVideoPlaybackSessionCache()

    /// Active dive overview heroes plus immediate pager neighbors.
    nonisolated static let capacity = 6

    struct SwiftUISnapshot {
        var playerItem: AVPlayerItem
        var resolvedKey: String
        var videoFidelity: DiveMediaVideoFidelity
        var isDisplayReady: Bool
        var posterImage: UIImage?
    }

    #if canImport(AVFoundation)
    private var playersByResolvedKey: [String: AVPlayer] = [:]
    #endif
    private var swiftUISnapshotsBySourceKey: [String: SwiftUISnapshot] = [:]
    private var accessOrder: [String] = []
    private var pinnedSourceIdentityKeys: Set<String> = []

    private init() {}

    func setPinnedSourceIdentityKeys(_ keys: Set<String>) {
        pinnedSourceIdentityKeys = keys
        for key in keys {
            touchAccess(key)
        }
    }

    func swiftUISnapshot(forSourceIdentityKey sourceKey: String) -> SwiftUISnapshot? {
        swiftUISnapshotsBySourceKey[sourceKey]
    }

    func storeSwiftUISnapshot(_ snapshot: SwiftUISnapshot, sourceIdentityKey sourceKey: String) {
        swiftUISnapshotsBySourceKey[sourceKey] = snapshot
        touchAccess(sourceKey)
        trimSwiftUISnapshotsToLimit()
    }

    func removeSwiftUISnapshot(forSourceIdentityKey sourceKey: String) {
        swiftUISnapshotsBySourceKey.removeValue(forKey: sourceKey)
        accessOrder.removeAll { $0 == sourceKey }
    }

    #if canImport(AVFoundation)
    func player(forResolvedKey resolvedKey: String) -> AVPlayer? {
        playersByResolvedKey[resolvedKey]
    }

    func store(player: AVPlayer, resolvedKey: String) {
        playersByResolvedKey[resolvedKey] = player
        touchAccess(resolvedKey)
        trimPlayersToLimit()
    }

    func removePlayer(forResolvedKey resolvedKey: String) {
        playersByResolvedKey.removeValue(forKey: resolvedKey)
        accessOrder.removeAll { $0 == resolvedKey }
    }

    /// Drops cached players and SwiftUI snapshots for one library asset (carousel re-activation).
    func invalidateLibraryPlayback(sourceIdentityKey: String) {
        removeSwiftUISnapshot(forSourceIdentityKey: sourceIdentityKey)
        let playerKeys = playersByResolvedKey.keys.filter {
            $0 == sourceIdentityKey || $0.hasPrefix("\(sourceIdentityKey)|")
        }
        for key in playerKeys {
            removePlayer(forResolvedKey: key)
        }
    }
    #endif

    func clear() {
        #if canImport(AVFoundation)
        for player in playersByResolvedKey.values {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        playersByResolvedKey.removeAll()
        #endif
        swiftUISnapshotsBySourceKey.removeAll()
        accessOrder.removeAll()
        pinnedSourceIdentityKeys.removeAll()
    }

    /// Keeps carousel playback snapshots; drops other cached players on background.
    func clearUnpinnedExcept(_ pinnedSourceKeys: Set<String>) {
        pinnedSourceIdentityKeys = pinnedSourceKeys

        let snapshotKeysToRemove = swiftUISnapshotsBySourceKey.keys.filter {
            !pinnedSourceKeys.contains($0)
        }
        for key in snapshotKeysToRemove {
            removeSwiftUISnapshot(forSourceIdentityKey: key)
        }

        #if canImport(AVFoundation)
        let playerKeysToRemove = playersByResolvedKey.keys.filter { resolvedKey in
            !pinnedSourceKeys.contains(where: { resolvedKey == $0 || resolvedKey.hasPrefix("\($0)|") })
        }
        for key in playerKeysToRemove {
            playersByResolvedKey.removeValue(forKey: key)?.pause()
            accessOrder.removeAll { $0 == key }
        }
        #endif
    }

    private func touchAccess(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func trimSwiftUISnapshotsToLimit() {
        while swiftUISnapshotsBySourceKey.count > Self.capacity {
            guard let evictKey = accessOrder.first(where: { key in
                swiftUISnapshotsBySourceKey[key] != nil && !pinnedSourceIdentityKeys.contains(key)
            }) else { break }
            swiftUISnapshotsBySourceKey.removeValue(forKey: evictKey)
            accessOrder.removeAll { $0 == evictKey }
        }
    }

    private func trimPlayersToLimit() {
        #if canImport(AVFoundation)
        while playersByResolvedKey.count > Self.capacity {
            guard let evictKey = accessOrder.first(where: { key in
                guard playersByResolvedKey[key] != nil else { return false }
                return !pinnedSourceIdentityKeys.contains(where: { key == $0 || key.hasPrefix("\($0)|") })
            }) else { break }
            playersByResolvedKey.removeValue(forKey: evictKey)?.pause()
            accessOrder.removeAll { $0 == evictKey }
        }
        #endif
    }
}

#if canImport(UIKit)
import UIKit
#endif
