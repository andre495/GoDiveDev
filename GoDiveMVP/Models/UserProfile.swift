import Foundation
import SwiftData

/// Locally persisted diver account (Sign in with Apple). One row per Apple user identifier on this device.
@Model
final class UserProfile {
    var id: UUID = UUID()
    /// Stable identifier from **`ASAuthorizationAppleIDCredential.user`**.
    var appleUserIdentifier: String = ""
    var displayName: String = ""
    /// Profile picture bytes (JPEG/PNG from photo picker).
    var profilePhoto: Data?
    /// DAN (Divers Alert Network) insurance membership number, when provided.
    var danInsuranceNumber: String?
    /// Onboarding activity preferences (logged-out welcome screen).
    var doesScubaDiving: Bool = false
    var doesFreeDiving: Bool = false
    var doesSnorkeling: Bool = false
    var createdAt: Date = Date()
    var lastSignedInAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \DiveActivity.owner)
    var diveActivitiesStorage: [DiveActivity]? = []
    @Transient
    var diveActivities: [DiveActivity] {
        get { diveActivitiesStorage ?? [] }
        set { diveActivitiesStorage = newValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \EquipmentItem.owner)
    var equipmentItemsStorage: [EquipmentItem]? = []
    @Transient
    var equipmentItems: [EquipmentItem] {
        get { equipmentItemsStorage ?? [] }
        set { equipmentItemsStorage = newValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \Certification.owner)
    var certificationsStorage: [Certification]? = []
    @Transient
    var certifications: [Certification] {
        get { certificationsStorage ?? [] }
        set { certificationsStorage = newValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \DiveBuddy.owner)
    var diveBuddiesStorage: [DiveBuddy]? = []
    @Transient
    var diveBuddies: [DiveBuddy] {
        get { diveBuddiesStorage ?? [] }
        set { diveBuddiesStorage = newValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \DiveTrip.owner)
    var diveTripsStorage: [DiveTrip]? = []
    @Transient
    var diveTrips: [DiveTrip] {
        get { diveTripsStorage ?? [] }
        set { diveTripsStorage = newValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \MarineLifeUserRecord.owner)
    var marineLifeUserRecordsStorage: [MarineLifeUserRecord]? = []
    @Transient
    var marineLifeUserRecords: [MarineLifeUserRecord] {
        get { marineLifeUserRecordsStorage ?? [] }
        set { marineLifeUserRecordsStorage = newValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \UserMarineLife.owner)
    var userMarineLifeSpeciesStorage: [UserMarineLife]? = []
    @Transient
    var userMarineLifeSpecies: [UserMarineLife] {
        get { userMarineLifeSpeciesStorage ?? [] }
        set { userMarineLifeSpeciesStorage = newValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \UserDiveSite.owner)
    var userDiveSitesStorage: [UserDiveSite]? = []
    @Transient
    var userDiveSites: [UserDiveSite] {
        get { userDiveSitesStorage ?? [] }
        set { userDiveSitesStorage = newValue }
    }

    /// Synced settings row (one per profile). Optional for CloudKit.
    @Relationship(deleteRule: .cascade, inverse: \UserPreferences.owner)
    var preferences: UserPreferences?

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
