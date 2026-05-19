import Foundation
import SwiftData

// MARK: - Certification

/// Diver certification card stored for the signed-in profile (agency, number, instructor, card images).
@Model
final class Certification {

    var id: UUID

    /// Training agency (e.g. **PADI**, **NAUI**, **SSI**).
    var agency: String
    /// Certification title (e.g. **Rescue Diver**, **Open Water**).
    var certName: String
    var certNumber: String
    var dateAttained: Date

    var instructor: String
    var instructorNumber: String
    var diveShop: String?

    /// When **`true`**, this card is the profile’s primary certification (at most one per owner).
    var isPrimaryCert: Bool

    /// Front of certification card (JPEG/PNG bytes from photo picker).
    var certFrontPicture: Data?
    /// Back of certification card (JPEG/PNG bytes from photo picker).
    var certBackPicture: Data?

    /// Denormalized for **`#Predicate`** / filtering; kept in sync with **`owner`**.
    var ownerProfileID: UUID?
    @Relationship
    var owner: UserProfile?

    init(
        id: UUID = UUID(),
        agency: String = "",
        certName: String = "",
        certNumber: String = "",
        dateAttained: Date = .now,
        instructor: String = "",
        instructorNumber: String = "",
        diveShop: String? = nil,
        isPrimaryCert: Bool = false,
        certFrontPicture: Data? = nil,
        certBackPicture: Data? = nil,
        ownerProfileID: UUID? = nil,
        owner: UserProfile? = nil
    ) {
        self.id = id
        self.agency = agency
        self.certName = certName
        self.certNumber = certNumber
        self.dateAttained = dateAttained
        self.instructor = instructor
        self.instructorNumber = instructorNumber
        self.diveShop = diveShop
        self.isPrimaryCert = isPrimaryCert
        self.certFrontPicture = certFrontPicture
        self.certBackPicture = certBackPicture
        self.ownerProfileID = ownerProfileID
        self.owner = owner
    }
}
