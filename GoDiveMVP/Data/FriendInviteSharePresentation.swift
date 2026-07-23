import Foundation

/// Active friend invite sheet payload — present only after Firestore + URL are ready.
struct FriendInviteSharePresentation: Identifiable, Equatable, Sendable {
    var id: String { token }
    var token: String
    var url: URL
}
