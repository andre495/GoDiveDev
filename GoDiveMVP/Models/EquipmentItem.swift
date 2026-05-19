import Foundation
import SwiftData

// MARK: - EquipmentItem

/// Diver-owned gear row for **Equipment Locker** (manufacturer, service schedule, photo, etc.).
@Model
final class EquipmentItem {

    var id: UUID

    var manufacturer: String
    var model: String
    /// Category label (e.g. **Regulator**, **BCD**, **Computer**).
    var type: String

    var isRetired: Bool
    /// When **`true`**, the item may be suggested automatically on new dives (future UX).
    var autoAdd: Bool

    var purchaseDate: Date?
    var purchasedShop: String?
    var price: Double?

    /// Last service date (derived from **next** − recurrence when both are set on save).
    var serviceDate: Date?
    /// Next service due date (from the add / edit form).
    var nextServiceDate: Date?
    /// Recurrence interval stored as calendar days (e.g. every **2** weeks → **14**).
    var serviceRecurrenceDays: Int?
    var serviceNotes: String?

    var notes: String?

    /// Stored photo bytes (e.g. JPEG or PNG from the photo picker).
    var equipmentPhoto: Data?

    /// Denormalized for **`#Predicate`** / locker filtering; kept in sync with **`owner`**.
    var ownerProfileID: UUID?
    @Relationship
    var owner: UserProfile?

    init(
        id: UUID = UUID(),
        manufacturer: String = "",
        model: String = "",
        type: String = "",
        isRetired: Bool = false,
        autoAdd: Bool = false,
        purchaseDate: Date? = nil,
        purchasedShop: String? = nil,
        price: Double? = nil,
        serviceDate: Date? = nil,
        nextServiceDate: Date? = nil,
        serviceRecurrenceDays: Int? = nil,
        serviceNotes: String? = nil,
        notes: String? = nil,
        equipmentPhoto: Data? = nil,
        ownerProfileID: UUID? = nil,
        owner: UserProfile? = nil
    ) {
        self.id = id
        self.manufacturer = manufacturer
        self.model = model
        self.type = type
        self.isRetired = isRetired
        self.autoAdd = autoAdd
        self.purchaseDate = purchaseDate
        self.purchasedShop = purchasedShop
        self.price = price
        self.serviceDate = serviceDate
        self.nextServiceDate = nextServiceDate
        self.serviceRecurrenceDays = serviceRecurrenceDays
        self.serviceNotes = serviceNotes
        self.notes = notes
        self.equipmentPhoto = equipmentPhoto
        self.ownerProfileID = ownerProfileID
        self.owner = owner
    }
}
