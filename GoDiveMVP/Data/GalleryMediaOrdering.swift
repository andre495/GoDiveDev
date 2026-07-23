import Foundation

/// Sendable gallery sort key — shared by dive derived snapshots and **`@MainActor`** media presentation.
struct GalleryMediaOrderFields: Sendable, Equatable {
    var id: UUID
    var capturedAt: Date?
    var sortOrder: Int

    nonisolated init(id: UUID, capturedAt: Date?, sortOrder: Int) {
        self.id = id
        self.capturedAt = capturedAt
        self.sortOrder = sortOrder
    }
}

enum GalleryMediaOrdering: Sendable {
    /// Oldest **`capturedAt`** first; undated last; then **`sortOrder`**, then **`id`**.
    nonisolated static func isOrderedBefore(_ lhs: GalleryMediaOrderFields, _ rhs: GalleryMediaOrderFields) -> Bool {
        switch (lhs.capturedAt, rhs.capturedAt) {
        case let (left?, right?):
            if left != right { return left < right }
        case (nil, .some):
            return false
        case (.some, nil):
            return true
        case (nil, nil):
            break
        }
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    nonisolated static func sortedSnapshots(_ snapshots: [DiveDerivedMediaSnapshot]) -> [DiveDerivedMediaSnapshot] {
        snapshots.sorted {
            isOrderedBefore(
                GalleryMediaOrderFields(id: $0.id, capturedAt: $0.capturedAt, sortOrder: $0.sortOrder),
                GalleryMediaOrderFields(id: $1.id, capturedAt: $1.capturedAt, sortOrder: $1.sortOrder)
            )
        }
    }
}
