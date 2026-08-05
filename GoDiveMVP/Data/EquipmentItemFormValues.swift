import Foundation

/// Draft values for the add / edit equipment sheet before persisting an **`EquipmentItem`**.
struct EquipmentItemFormValues: Equatable, Sendable {
    var manufacturer: String = ""
    var model: String = ""
    var gearType: EquipmentGearType = .other
    var isRetired: Bool = false
    var autoAdd: Bool = false

    var includesPurchaseDate: Bool = false
    var purchaseDate: Date = .now

    var purchasedShop: String = ""
    var priceText: String = ""

    var includesRecurringService: Bool = false
    var nextServiceDate: Date = .now

    var recurrenceIntervalCount: Int = 1
    var recurrenceUnit: EquipmentRecurrenceUnit = .years

    /// Empty set = no notifications. New drafts follow Settings → Gear servicing (1 week or off).
    var serviceReminderOffsets: Set<EquipmentServiceReminderOffset> = []

    var serviceNotes: String = ""

    var notes: String = ""
    var equipmentPhoto: Data?

    var canSave: Bool {
        !manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var resolvedRecurrenceDays: Int? {
        EquipmentServiceSchedule.recurrenceDays(interval: recurrenceIntervalCount, unit: recurrenceUnit)
    }

    func parsedPrice() -> Double? {
        let trimmed = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    /// Empty draft for **Add equipment** (custom **`init(from:)`** replaces the memberwise default).
    init() {
        serviceReminderOffsets = EquipmentServiceReminderSchedule.defaultOffsets()
    }

    init(from item: EquipmentItem) {
        manufacturer = item.manufacturer
        model = item.model
        gearType = EquipmentGearType.resolved(
            storedGearType: item.gearType,
            legacyType: item.type
        )
        isRetired = item.isRetired
        autoAdd = item.autoAdd

        if let purchaseDate = item.purchaseDate {
            includesPurchaseDate = true
            self.purchaseDate = purchaseDate
        }
        purchasedShop = item.purchasedShop ?? ""
        if let price = item.price {
            priceText = String(price)
        }

        if let days = item.serviceRecurrenceDays,
           let parts = EquipmentServiceSchedule.recurrenceIntervalAndUnit(forStoredDays: days) {
            recurrenceIntervalCount = parts.interval
            recurrenceUnit = parts.unit
        }

        if let next = item.nextServiceDate {
            includesRecurringService = true
            nextServiceDate = next
        } else if let last = item.serviceDate,
                  let days = item.serviceRecurrenceDays,
                  let inferredNext = EquipmentServiceSchedule.nextServiceDate(
                    lastServiceDate: last,
                    recurrenceDays: days
                  ) {
            includesRecurringService = true
            nextServiceDate = inferredNext
        } else if item.serviceRecurrenceDays != nil {
            includesRecurringService = true
        }

        if includesRecurringService {
            serviceReminderOffsets = EquipmentServiceReminderSchedule.decode(item.serviceReminderOffsetsRaw)
        } else {
            serviceReminderOffsets = EquipmentServiceReminderSchedule.defaultOffsets()
        }

        serviceNotes = item.serviceNotes ?? ""
        notes = item.notes ?? ""
        equipmentPhoto = item.equipmentPhoto
    }

    /// Persisted reminder token when recurring service is on; otherwise **`nil`**.
    var persistedServiceReminderOffsetsRaw: String? {
        guard includesRecurringService else { return nil }
        return EquipmentServiceReminderSchedule.encode(serviceReminderOffsets)
    }

    mutating func setServiceReminderOffset(_ offset: EquipmentServiceReminderOffset, enabled: Bool) {
        if enabled {
            serviceReminderOffsets.insert(offset)
        } else {
            serviceReminderOffsets.remove(offset)
        }
    }

    mutating func setNoServiceReminders() {
        serviceReminderOffsets = []
    }

    /// Used when the user turns **No notifications** off — always offers the 1-week starting point
    /// (even if the global gear default is off), since they are explicitly enabling reminders on this item.
    mutating func restoreDefaultServiceRemindersIfEmpty() {
        if serviceReminderOffsets.isEmpty {
            serviceReminderOffsets = EquipmentServiceReminderSchedule.enabledDefaultOffsets
        }
    }

    func apply(to item: EquipmentItem) {
        let shop = purchasedShop.trimmingCharacters(in: .whitespacesAndNewlines)
        let service = serviceNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let recurrenceDays = includesRecurringService ? resolvedRecurrenceDays : nil
        let nextDate = includesRecurringService ? nextServiceDate : nil
        let lastDate: Date?
        if let nextDate, let recurrenceDays {
            lastDate = EquipmentServiceSchedule.lastServiceDate(
                nextServiceDate: nextDate,
                recurrenceDays: recurrenceDays
            )
        } else {
            lastDate = nil
        }

        item.manufacturer = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        item.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        item.gearType = gearType.rawValue
        item.type = gearType.displayName
        item.isRetired = isRetired
        item.autoAdd = autoAdd
        item.purchaseDate = includesPurchaseDate ? purchaseDate : nil
        item.purchasedShop = shop.isEmpty ? nil : shop
        item.price = parsedPrice()
        item.serviceDate = lastDate
        item.nextServiceDate = nextDate
        item.serviceRecurrenceDays = recurrenceDays
        item.serviceReminderOffsetsRaw = persistedServiceReminderOffsetsRaw
        item.serviceNotes = service.isEmpty ? nil : service
        item.notes = note.isEmpty ? nil : note
        item.equipmentPhoto = equipmentPhoto
    }

    func makeEquipmentItem() -> EquipmentItem {
        let shop = purchasedShop.trimmingCharacters(in: .whitespacesAndNewlines)
        let service = serviceNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let recurrenceDays = includesRecurringService ? resolvedRecurrenceDays : nil
        let nextDate = includesRecurringService ? nextServiceDate : nil
        let lastDate: Date?
        if let nextDate, let recurrenceDays {
            lastDate = EquipmentServiceSchedule.lastServiceDate(
                nextServiceDate: nextDate,
                recurrenceDays: recurrenceDays
            )
        } else {
            lastDate = nil
        }

        return EquipmentItem(
            manufacturer: manufacturer.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            type: gearType.displayName,
            gearType: gearType.rawValue,
            isRetired: isRetired,
            autoAdd: autoAdd,
            purchaseDate: includesPurchaseDate ? purchaseDate : nil,
            purchasedShop: shop.isEmpty ? nil : shop,
            price: parsedPrice(),
            serviceDate: lastDate,
            nextServiceDate: nextDate,
            serviceRecurrenceDays: recurrenceDays,
            serviceReminderOffsetsRaw: persistedServiceReminderOffsetsRaw,
            serviceNotes: service.isEmpty ? nil : service,
            notes: note.isEmpty ? nil : note,
            equipmentPhoto: equipmentPhoto
        )
    }
}
