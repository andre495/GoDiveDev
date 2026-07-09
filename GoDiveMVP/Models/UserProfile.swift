import Foundation
import SwiftData

/// Locally persisted diver account (Sign in with Apple). One row per Apple user identifier on this device.
@Model
final class UserProfile {
    var id: UUID
    /// Stable identifier from **`ASAuthorizationAppleIDCredential.user`**.
    var appleUserIdentifier: String
    var displayName: String
    /// Profile picture bytes (JPEG/PNG from photo picker).
    var profilePhoto: Data?
    /// DAN (Divers Alert Network) insurance membership number, when provided.
    var danInsuranceNumber: String?
    /// Onboarding activity preferences (logged-out welcome screen).
    var doesScubaDiving: Bool = false
    var doesFreeDiving: Bool = false
    var doesSnorkeling: Bool = false
    var createdAt: Date
    var lastSignedInAt: Date

    @Relationship(deleteRule: .cascade, inverse: \DiveActivity.owner)
    var diveActivities: [DiveActivity] = []

    @Relationship(deleteRule: .cascade, inverse: \EquipmentItem.owner)
    var equipmentItems: [EquipmentItem] = []

    @Relationship(deleteRule: .cascade, inverse: \Certification.owner)
    var certifications: [Certification] = []

    @Relationship(deleteRule: .cascade, inverse: \DiveBuddy.owner)
    var diveBuddies: [DiveBuddy] = []

    @Relationship(deleteRule: .cascade, inverse: \DiveTrip.owner)
    var diveTrips: [DiveTrip] = []

    init(
        id: UUID = UUID(),
        appleUserIdentifier: String,
        displayName: String,
        profilePhoto: Data? = nil,
        danInsuranceNumber: String? = nil,
        doesScubaDiving: Bool = false,
        doesFreeDiving: Bool = false,
        doesSnorkeling: Bool = false,
        createdAt: Date = .now,
        lastSignedInAt: Date = .now
    ) {
        self.id = id
        self.appleUserIdentifier = appleUserIdentifier
        self.displayName = displayName
        self.profilePhoto = profilePhoto
        self.danInsuranceNumber = danInsuranceNumber
        self.doesScubaDiving = doesScubaDiving
        self.doesFreeDiving = doesFreeDiving
        self.doesSnorkeling = doesSnorkeling
        self.createdAt = createdAt
        self.lastSignedInAt = lastSignedInAt
    }
}
