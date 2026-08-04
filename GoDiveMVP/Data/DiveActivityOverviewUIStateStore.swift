import Foundation

/// Restores dive overview chrome after nested **`NavigationStack`** pushes (tags, species, buddies, sites).
/// Snapshots are discarded when the activity leaves the hosting stack (e.g. back to Logbook) so reopen is map-first.
struct DiveActivityOverviewUISnapshot: Sendable, Equatable {
    var selectedActivityTab: DiveActivityTab
    var overviewSheetDetent: DiveActivityOverviewDetent
    var isOverviewPanelPresented: Bool
    var selectedDiveMediaPhotoID: UUID?
    var overviewPanelScrollOffsetY: CGFloat

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.selectedActivityTab == rhs.selectedActivityTab
            && lhs.overviewSheetDetent == rhs.overviewSheetDetent
            && lhs.isOverviewPanelPresented == rhs.isOverviewPanelPresented
            && lhs.selectedDiveMediaPhotoID == rhs.selectedDiveMediaPhotoID
            && lhs.overviewPanelScrollOffsetY == rhs.overviewPanelScrollOffsetY
    }
}

struct SnorkelActivityOverviewUISnapshot: Sendable, Equatable {
    var selectedActivityTab: SnorkelActivityTab
    var overviewSheetDetent: DiveActivityOverviewDetent
    var isOverviewPanelPresented: Bool
    var selectedMediaPhotoID: UUID?
    var overviewPanelScrollOffsetY: CGFloat
}

enum DiveActivityOverviewUIStateStore: Sendable {

    private nonisolated(unsafe) static var snapshotsByActivityID: [UUID: DiveActivityOverviewUISnapshot] = [:]
    private nonisolated(unsafe) static var snorkelSnapshotsByActivityID: [UUID: SnorkelActivityOverviewUISnapshot] = [:]
    /// Blocks **`onDisappear`** re-persist after the activity route left the stack.
    private nonisolated(unsafe) static var divePersistSuppressedIDs: Set<UUID> = []
    private nonisolated(unsafe) static var snorkelPersistSuppressedIDs: Set<UUID> = []

    #if DEBUG
    nonisolated static func resetForTesting() {
        snapshotsByActivityID = [:]
        snorkelSnapshotsByActivityID = [:]
        divePersistSuppressedIDs = []
        snorkelPersistSuppressedIDs = []
    }
    #endif

    nonisolated static func snapshot(for activityID: UUID) -> DiveActivityOverviewUISnapshot? {
        snapshotsByActivityID[activityID]
    }

    nonisolated static func save(_ snapshot: DiveActivityOverviewUISnapshot, for activityID: UUID) {
        guard !divePersistSuppressedIDs.contains(activityID) else { return }
        snapshotsByActivityID[activityID] = snapshot
    }

    /// Updates only scroll offset on an existing snapshot (e.g. while scrolling before a nested push).
    nonisolated static func mergeScrollOffset(_ offset: CGFloat, for activityID: UUID) {
        guard !divePersistSuppressedIDs.contains(activityID) else { return }
        guard offset > 4, var snapshot = snapshotsByActivityID[activityID] else { return }
        snapshot.overviewPanelScrollOffsetY = offset
        snapshotsByActivityID[activityID] = snapshot
    }

    nonisolated static func remove(activityID: UUID) {
        snapshotsByActivityID.removeValue(forKey: activityID)
    }

    /// Drop chrome for a visit that left the hosting stack (map-first on next open).
    nonisolated static func discardDiveSession(activityID: UUID) {
        divePersistSuppressedIDs.insert(activityID)
        snapshotsByActivityID.removeValue(forKey: activityID)
    }

    /// Re-enable persist while the overview is on-screen again.
    nonisolated static func noteDiveSessionActive(activityID: UUID) {
        divePersistSuppressedIDs.remove(activityID)
    }

    nonisolated static func snorkelSnapshot(for activityID: UUID) -> SnorkelActivityOverviewUISnapshot? {
        snorkelSnapshotsByActivityID[activityID]
    }

    nonisolated static func saveSnorkel(_ snapshot: SnorkelActivityOverviewUISnapshot, for activityID: UUID) {
        guard !snorkelPersistSuppressedIDs.contains(activityID) else { return }
        snorkelSnapshotsByActivityID[activityID] = snapshot
    }

    nonisolated static func removeSnorkel(activityID: UUID) {
        snorkelSnapshotsByActivityID.removeValue(forKey: activityID)
    }

    nonisolated static func discardSnorkelSession(activityID: UUID) {
        snorkelPersistSuppressedIDs.insert(activityID)
        snorkelSnapshotsByActivityID.removeValue(forKey: activityID)
    }

    nonisolated static func noteSnorkelSessionActive(activityID: UUID) {
        snorkelPersistSuppressedIDs.remove(activityID)
    }
}
