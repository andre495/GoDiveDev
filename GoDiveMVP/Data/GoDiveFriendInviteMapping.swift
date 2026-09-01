import Foundation

/// Pure mapping for friend invites + friendship docs (testable without Firebase).
enum GoDiveFriendInviteMapping: Sendable {
    nonisolated static let inviteCollection = "friendInvites"
    nonisolated static let friendshipsCollection = "friendships"
    nonisolated static let inviteStatusOpen = "open"
    nonisolated static let inviteStatusRedeemed = "redeemed"
    nonisolated static let inviteStatusRevoked = "revoked"
    nonisolated static let friendshipStatusActive = "active"
    /// Soft cap for small networks.
    nonisolated static let maxFriendsPerUser = 50
    /// Soft-expire unused invites (client + Firestore rules check **`expiresAt`**).
    nonisolated static let inviteTimeToLiveSeconds: TimeInterval = 24 * 60 * 60
    nonisolated static let tokenByteCount = 16

    struct InviteDraft: Equatable, Sendable {
        var token: String
        var fromUid: String
        var fromDisplayName: String?
        var status: String
        var createdAt: Date
        var expiresAt: Date
        var redeemedBy: String?
    }

    struct FriendshipDraft: Equatable, Sendable {
        var friendshipID: String
        var members: [String]
        var status: String
        var inviteToken: String
        var createdAt: Date
        var memberDisplayNames: [String: String]
    }

    /// Opaque URL-safe token (hex).
    nonisolated static func makeToken(byteCount: Int = tokenByteCount) -> String {
        var bytes = [UInt8](repeating: 0, count: max(8, byteCount))
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            bytes = (0 ..< bytes.count).map { _ in UInt8.random(in: 0 ... 255) }
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func inviteDraft(
        fromUid: String,
        token: String = makeToken(),
        now: Date = Date(),
        timeToLive: TimeInterval = inviteTimeToLiveSeconds,
        fromDisplayName: String? = nil
    ) -> InviteDraft {
        let trimmedUID = fromUid.trimmingCharacters(in: .whitespacesAndNewlines)
        return InviteDraft(
            token: token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            fromUid: trimmedUID,
            fromDisplayName: sanitizedFromDisplayName(fromDisplayName),
            status: inviteStatusOpen,
            createdAt: now,
            expiresAt: now.addingTimeInterval(timeToLive),
            redeemedBy: nil
        )
    }

    nonisolated static func inviteFields(from draft: InviteDraft) -> [String: Any] {
        var fields: [String: Any] = [
            "fromUid": draft.fromUid,
            "status": draft.status,
            "createdAt": draft.createdAt,
            "expiresAt": draft.expiresAt,
        ]
        if let fromDisplayName = draft.fromDisplayName {
            fields["fromDisplayName"] = fromDisplayName
        }
        if let redeemedBy = draft.redeemedBy {
            fields["redeemedBy"] = redeemedBy
        }
        return fields
    }

    /// True for empty strings and the onboarding placeholder **Diver**.
    nonisolated static func isPlaceholderDisplayName(_ raw: String?) -> Bool {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return true }
        return trimmed.caseInsensitiveCompare(UserProfileStore.defaultDisplayName) == .orderedSame
    }

    /// Trimmed invite / directory name; `nil` when empty or the placeholder **Diver**.
    nonisolated static func sanitizedFromDisplayName(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !isPlaceholderDisplayName(trimmed) else { return nil }
        return trimmed
    }

    /// First usable (non-placeholder) name from local profile, Auth, Apple cache, then returning hint.
    nonisolated static func resolvedPublisherDisplayName(
        localProfileName: String?,
        authDisplayName: String? = nil,
        cachedAppleName: String? = nil,
        returningHintName: String? = nil
    ) -> String? {
        [
            localProfileName,
            authDisplayName,
            cachedAppleName,
            returningHintName,
        ]
        .compactMap { sanitizedFromDisplayName($0) }
        .first
    }

    /// Prefers the live directory name; falls back to the invite / friendship snapshot when the
    /// directory doc is missing or still the placeholder **Diver**.
    nonisolated static func resolvedInviteDisplayName(
        directoryDisplayName: String?,
        inviteFromDisplayName: String?
    ) -> String {
        if let directory = sanitizedFromDisplayName(directoryDisplayName) {
            return directory
        }
        if let snapshot = sanitizedFromDisplayName(inviteFromDisplayName) {
            return snapshot
        }
        let directory = directoryDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return directory.isEmpty ? UserProfileStore.defaultDisplayName : directory
    }

    /// Snapshot name for `uid` from a friendship **`memberDisplayNames`** map (Firestore `[String: Any]`).
    nonisolated static func memberDisplayName(for uid: String, in raw: Any?) -> String? {
        let target = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return nil }
        let map: [String: Any]
        if let anyMap = raw as? [String: Any] {
            map = anyMap
        } else if let stringMap = raw as? [String: String] {
            map = stringMap
        } else {
            return nil
        }
        if let exact = sanitizedFromDisplayName(map[target] as? String) {
            return exact
        }
        for (key, value) in map {
            if key.trimmingCharacters(in: .whitespacesAndNewlines) == target {
                return sanitizedFromDisplayName(value as? String)
            }
        }
        return nil
    }

    /// True when any active friendship `members` list includes `uid`.
    ///
    /// Used instead of `getDocument` on `friendships/{sortedPair}`: that path is
    /// permission-denied when the doc does not exist yet (`resource.data.members`).
    nonisolated static func hasActiveFriendship(
        with uid: String,
        memberLists: [[String]]
    ) -> Bool {
        let target = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return false }
        return memberLists.contains { members in
            members.contains {
                $0.trimmingCharacters(in: .whitespacesAndNewlines) == target
            }
        }
    }

    /// Deterministic doc id for a pair of Firebase UIDs (order-independent).
    nonisolated static func friendshipID(uidA: String, uidB: String) -> String {
        let a = uidA.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = uidB.trimmingCharacters(in: .whitespacesAndNewlines)
        return a < b ? "\(a)_\(b)" : "\(b)_\(a)"
    }

    nonisolated static func friendshipDraft(
        uidA: String,
        uidB: String,
        inviteToken: String,
        now: Date = Date(),
        displayNameA: String? = nil,
        displayNameB: String? = nil
    ) -> FriendshipDraft {
        let a = uidA.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = uidB.trimmingCharacters(in: .whitespacesAndNewlines)
        let members = a < b ? [a, b] : [b, a]
        var memberDisplayNames: [String: String] = [:]
        if let nameA = sanitizedFromDisplayName(displayNameA) {
            memberDisplayNames[a] = nameA
        }
        if let nameB = sanitizedFromDisplayName(displayNameB) {
            memberDisplayNames[b] = nameB
        }
        return FriendshipDraft(
            friendshipID: friendshipID(uidA: a, uidB: b),
            members: members,
            status: friendshipStatusActive,
            inviteToken: inviteToken.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            createdAt: now,
            memberDisplayNames: memberDisplayNames
        )
    }

    nonisolated static func friendshipFields(from draft: FriendshipDraft) -> [String: Any] {
        var fields: [String: Any] = [
            "members": draft.members,
            "status": draft.status,
            "inviteToken": draft.inviteToken,
            "createdAt": draft.createdAt,
        ]
        if !draft.memberDisplayNames.isEmpty {
            fields["memberDisplayNames"] = draft.memberDisplayNames
        }
        return fields
    }

    nonisolated static func isInviteOpen(
        status: String,
        expiresAt: Date,
        now: Date = Date()
    ) -> Bool {
        status == inviteStatusOpen && expiresAt > now
    }

    enum RedeemValidationError: Error, Equatable, Sendable {
        case inviteMissing
        case inviteNotOpen
        case inviteExpired
        case selfInvite
        case alreadyFriends
        case friendCapReached
    }

    /// Validates redeem before writing Firestore (pure).
    nonisolated static func validateRedeem(
        inviteFromUid: String?,
        inviteStatus: String?,
        inviteExpiresAt: Date?,
        redeemingUid: String,
        alreadyFriends: Bool,
        currentFriendCount: Int,
        now: Date = Date()
    ) -> Result<String, RedeemValidationError> {
        guard let fromUid = inviteFromUid?.trimmingCharacters(in: .whitespacesAndNewlines),
              !fromUid.isEmpty
        else {
            return .failure(.inviteMissing)
        }
        let me = redeemingUid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !me.isEmpty else { return .failure(.inviteMissing) }
        guard me != fromUid else { return .failure(.selfInvite) }
        guard let status = inviteStatus, status == inviteStatusOpen else {
            return .failure(.inviteNotOpen)
        }
        guard let expiresAt = inviteExpiresAt, expiresAt > now else {
            return .failure(.inviteExpired)
        }
        if alreadyFriends { return .failure(.alreadyFriends) }
        if currentFriendCount >= maxFriendsPerUser {
            return .failure(.friendCapReached)
        }
        return .success(fromUid)
    }

    nonisolated static func otherMember(members: [String], excluding uid: String) -> String? {
        let me = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        return members.first { $0 != me }
    }
}
