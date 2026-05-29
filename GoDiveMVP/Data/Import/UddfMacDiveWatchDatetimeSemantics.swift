import Foundation

/// How MacDive stores naive **`informationbeforedive/datetime`** depends on the source dive computer.
///
/// - **Suunto** (and similar): wall clock at the dive site (**dive-local**).
/// - **Garmin FIT** imports: **UTC** wall clock (MacDive lists Descent gear under **`variouspieces`**, not **`divecomputer`**).
///
/// Kept outside **`DiveActivity.swift`** with explicit **nonisolated** **`Equatable`** so **`@Model`** does not infer MainActor isolation (Swift 6).
enum UddfMacDiveWatchDatetimeSemantics: Sendable {
    case diveLocalWallTime
    case utcWallClock
}

extension UddfMacDiveWatchDatetimeSemantics: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.diveLocalWallTime, .diveLocalWallTime), (.utcWallClock, .utcWallClock):
            return true
        default:
            return false
        }
    }
}

/// One row from the UDDF owner **`equipment`** catalog (linked from **`equipmentused`**).
struct UddfEquipmentCatalogItem: Sendable {
    var id: String
    var kind: String
    var name: String
    var model: String
    var manufacturerName: String
}

enum UddfMacDiveWatchDatetimeSemanticsResolver: Sendable {

    /// Classifies naive **`datetime`** handling from gear linked on the dive.
    nonisolated static func classify(
        equipmentUsedRefs: [String],
        catalog: [String: UddfEquipmentCatalogItem]
    ) -> UddfMacDiveWatchDatetimeSemantics? {
        let used = equipmentUsedRefs.compactMap { catalog[$0] }
        guard !used.isEmpty else { return nil }

        let watchSources = used.filter(isLikelyDiveWatchSource)
        if watchSources.contains(where: isGarminWatchSource) {
            return .utcWallClock
        }
        if watchSources.contains(where: isStandardDiveComputer) {
            return .diveLocalWallTime
        }
        return nil
    }

    nonisolated private static func isLikelyDiveWatchSource(_ item: UddfEquipmentCatalogItem) -> Bool {
        if isStandardDiveComputer(item) { return true }
        if item.kind == "watch" { return true }
        return isGarminWatchSource(item)
    }

    nonisolated private static func isStandardDiveComputer(_ item: UddfEquipmentCatalogItem) -> Bool {
        item.kind == "divecomputer"
    }

    nonisolated private static func isGarminWatchSource(_ item: UddfEquipmentCatalogItem) -> Bool {
        let blob = searchableBlob(for: item)
        if blob.contains("garmin") {
            if blob.contains("transceiver"), !blob.contains("descent") {
                return false
            }
            return true
        }
        if blob.contains("descent") {
            return blob.contains("mk") || blob.contains("g1") || blob.contains("g2") || blob.contains("gis")
        }
        return false
    }

    nonisolated private static func searchableBlob(for item: UddfEquipmentCatalogItem) -> String {
        [item.kind, item.name, item.model, item.manufacturerName]
            .joined(separator: " ")
            .lowercased()
    }
}
