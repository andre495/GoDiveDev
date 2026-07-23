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
    nonisolated static let inviteTimeToLiveSeconds: TimeInterval = 7 * 24 * 60 * 60
    nonisolated static let tokenByteCount = 16

    struct InviteDraft: Equatable, Sendable {
        var token: String
        var fromUid: String
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
        timeToLive: TimeInterval = inviteTimeToLiveSeconds
    ) -> InviteDraft {
        let trimmedUID = fromUid.trimmingCharacters(in: .whitespacesAndNewlines)
        return InviteDraft(
            token: token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            fromUid: trimmedUID,
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
        if let redeemedBy = draft.redeemedBy {
            fields["redeemedBy"] = redeemedBy
        }
        return fields
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
        now: Date = Date()
    ) -> FriendshipDraft {
        let a = uidA.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = uidB.trimmingCharacters(in: .whitespacesAndNewlines)
        let members = a < b ? [a, b] : [b, a]
        return FriendshipDraft(
            friendshipID: friendshipID(uidA: a, uidB: b),
            members: members,
            status: friendshipStatusActive,
            inviteToken: inviteToken.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            createdAt: now
        )
    }

    nonisolated static func friendshipFields(from draft: FriendshipDraft) -> [String: Any] {
        [
            "members": draft.members,
            "status": draft.status,
            "inviteToken": draft.inviteToken,
            "createdAt": draft.createdAt,
        ]
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
