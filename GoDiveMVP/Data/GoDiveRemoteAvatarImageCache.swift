import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Presentation helpers for remote friend avatar URLs (Firebase Storage `photoURL`).
enum GoDiveRemoteAvatarPresentation: Sendable {
    /// Unique, policy-gated avatar URLs from a Buddy Feed window (for disk prefetch).
    /// Includes post owner URLs plus tagged / current-user URLs from **`avatarLookup`**.
    nonisolated static func buddyFeedAvatarPrefetchURLs(
        rows: [LogbookBuddyFeedPresentation.Row],
        startIndex: Int,
        count: Int = 12,
        avatarLookup: BuddyFeedAvatarLookup = .empty
    ) -> [String] {
        guard count > 0, startIndex >= 0, startIndex < rows.count else { return [] }
        let end = min(rows.count, startIndex + count)
        var seen = Set<String>()
        var urls: [String] = []
        urls.reserveCapacity(min(count, end - startIndex) * 2)

        func append(_ raw: String?) {
            guard let key = cacheKey(for: raw ?? ""),
                  seen.insert(key).inserted
            else { return }
            urls.append(key)
        }

        for index in startIndex ..< end {
            let row = rows[index]
            append(row.friendPhotoURL)
            let taggedUIDs = LogbookBuddyFeedPresentation.feedTaggedBuddies(for: row.dive)
                .compactMap(\.firebaseUID)
            for url in avatarLookup.prefetchablePhotoURLs(taggedFirebaseUIDs: taggedUIDs) {
                append(url)
            }
        }
        return urls
    }

    nonisolated static func cacheKey(for photoURL: String) -> String? {
        let trimmed = photoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              GoDiveRemoteURLPolicy.sanitizedFirebaseStorageURL(from: trimmed) != nil
        else { return nil }
        return trimmed
    }
}

#if canImport(UIKit)
/// In-memory **`UIImage`** reuse for friend avatars, backed by **`GoDiveSharedMediaCache`** (`.thumb` disk LRU).
@MainActor
final class GoDiveRemoteAvatarImageCache {
    static let shared = GoDiveRemoteAvatarImageCache()

    private var imagesByURL: [String: UIImage] = [:]

    private init() {}

    func cachedImage(for photoURL: String?) -> UIImage? {
        guard let key = GoDiveRemoteAvatarPresentation.cacheKey(for: photoURL ?? "") else { return nil }
        return imagesByURL[key]
    }

    func image(
        for photoURL: String?,
        allowsNetworkFetch: Bool
    ) async -> UIImage? {
        guard let key = GoDiveRemoteAvatarPresentation.cacheKey(for: photoURL ?? "") else { return nil }
        if let cached = imagesByURL[key] {
            return cached
        }
        let loaded = await GoDiveSharedMediaCache.shared.image(
            remoteURLString: key,
            tier: .thumb,
            allowsNetworkFetch: allowsNetworkFetch
        )
        if let loaded {
            imagesByURL[key] = loaded
        }
        return loaded
    }

    /// Test hook — clears in-memory entries (disk cache untouched).
    func removeAllForTesting() {
        imagesByURL.removeAll()
    }
}
#endif
