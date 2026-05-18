import Foundation
import SwiftData

/// Locally persisted diver account (Sign in with Apple). One row per Apple user identifier on this device.
@Model
final class UserProfile {
    var id: UUID
    /// Stable identifier from **`ASAuthorizationAppleIDCredential.user`**.
    var appleUserIdentifier: String
    var displayName: String
    var createdAt: Date
    var lastSignedInAt: Date

    @Relationship(deleteRule: .cascade, inverse: \DiveActivity.owner)
    var diveActivities: [DiveActivity] = []

    init(
        id: UUID = UUID(),
        appleUserIdentifier: String,
        displayName: String,
        createdAt: Date = .now,
        lastSignedInAt: Date = .now
    ) {
        self.id = id
        self.appleUserIdentifier = appleUserIdentifier
        self.displayName = displayName
        self.createdAt = createdAt
        self.lastSignedInAt = lastSignedInAt
    }
}
