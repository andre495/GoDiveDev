import Foundation

/// Resolves friend-profile hero media for the media/map toggle (account `profileHero` first).
enum FriendProfileHeroPresentation: Sendable {
    struct ResolvedHero: Equatable, Sendable {
        var url: URL
        var kind: GoDiveProfileHeroMediaKind
    }

    /// Account-level Firebase hero when present; otherwise newest shared dive featured media.
    nonisolated static func resolvedHero(
        profileHeroURL: String?,
        profileHeroMediaKind: GoDiveProfileHeroMediaKind?,
        sharedDives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive] = []
    ) -> ResolvedHero? {
        if let accountHero = resolvedAccountHero(
            profileHeroURL: profileHeroURL,
            profileHeroMediaKind: profileHeroMediaKind
        ) {
            return accountHero
        }
        return resolvedSharedDiveHero(from: sharedDives)
    }

    nonisolated static func hasAssociatedMedia(
        profileHeroURL: String?,
        profileHeroMediaKind: GoDiveProfileHeroMediaKind?,
        sharedDives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive] = []
    ) -> Bool {
        resolvedHero(
            profileHeroURL: profileHeroURL,
            profileHeroMediaKind: profileHeroMediaKind,
            sharedDives: sharedDives
        ) != nil
    }

    /// Prefer explicit Firestore kind; otherwise infer from the Storage object path / extension.
    nonisolated static func resolvedAccountHero(
        profileHeroURL: String?,
        profileHeroMediaKind: GoDiveProfileHeroMediaKind?
    ) -> ResolvedHero? {
        let raw = profileHeroURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty,
              let url = GoDiveRemoteURLPolicy.sanitizedFirebaseStorageURL(from: raw)
        else { return nil }

        let kind = profileHeroMediaKind ?? inferredKind(fromURLString: raw)
        guard let kind else { return nil }
        return ResolvedHero(url: url, kind: kind)
    }

    nonisolated static func inferredKind(fromURLString raw: String) -> GoDiveProfileHeroMediaKind? {
        let lower = raw.lowercased()
        // Prefer path tokens used by **`GoDiveFirebaseProfileHeroStorage`**, then file extensions.
        if lower.contains("profilehero.mp4") || lower.contains(".mp4") || lower.contains(".mov") {
            return .video
        }
        if lower.contains("profilehero.jpg")
            || lower.contains("profilehero.jpeg")
            || lower.contains(".jpg")
            || lower.contains(".jpeg")
            || lower.contains(".png")
            || lower.contains(".webp")
        {
            return .image
        }
        return nil
    }

    /// Newest shared dive’s featured still/video (content URL preferred, then thumbnail).
    nonisolated static func resolvedSharedDiveHero(
        from dives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive]
    ) -> ResolvedHero? {
        let ordered = dives.sorted { lhs, rhs in
            let left = lhs.startTime ?? lhs.sharedAt ?? .distantPast
            let right = rhs.startTime ?? rhs.sharedAt ?? .distantPast
            if left != right { return left > right }
            return lhs.id > rhs.id
        }
        for dive in ordered {
            guard let item = FriendSharedMediaPresentation.tileFeaturedDisplayItem(for: dive) else {
                continue
            }
            let rawURL = item.contentURL ?? item.thumbnailURL
            guard let rawURL,
                  let url = GoDiveRemoteURLPolicy.sanitizedFirebaseStorageURL(from: rawURL)
            else { continue }
            let kind: GoDiveProfileHeroMediaKind = item.kind == .video ? .video : .image
            return ResolvedHero(url: url, kind: kind)
        }
        return nil
    }
}
