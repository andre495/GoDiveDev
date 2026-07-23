import Foundation
import SwiftData

/// Debounced upsert / republish of friend-visible dive projections after local log changes.
@MainActor
enum GoDiveFriendShareRefreshCoordinator {
    private static var pendingTask: Task<Void, Never>?
    private static var pendingDiveIDs: Set<UUID> = []
    private static var pendingFullRepublish = false
    private static var didSaveObserver: NSObjectProtocol?
    private static var explicitChangeObserver: NSObjectProtocol?
    private static var observedOwnerProfileID: UUID?
    private static weak var observedModelContext: ModelContext?

    /// Watches the signed-in user store for saves that touch friend-shared dive fields.
    static func startObservingSaves(
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) {
        if observedOwnerProfileID == ownerProfileID, observedModelContext === modelContext, didSaveObserver != nil {
            return
        }
        stopObservingSaves()
        observedOwnerProfileID = ownerProfileID
        observedModelContext = modelContext

        didSaveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: modelContext,
            queue: .main
        ) { notification in
            let identifiers = GoDiveFriendShareAffectedDiveIDs.changedIdentifiers(
                from: notification.userInfo
            )
            Task { @MainActor in
                handleDidSave(identifiers: identifiers)
            }
        }

        explicitChangeObserver = NotificationCenter.default.addObserver(
            forName: .diveLogForFriendShareDidChange,
            object: nil,
            queue: .main
        ) { notification in
            let diveID = DiveLogForFriendShareChangeNotification.diveID(from: notification)
            Task { @MainActor in
                handleExplicitChange(diveID: diveID)
            }
        }
    }

    static func stopObservingSaves() {
        if let didSaveObserver {
            NotificationCenter.default.removeObserver(didSaveObserver)
            self.didSaveObserver = nil
        }
        if let explicitChangeObserver {
            NotificationCenter.default.removeObserver(explicitChangeObserver)
            self.explicitChangeObserver = nil
        }
        observedOwnerProfileID = nil
        observedModelContext = nil
        pendingTask?.cancel()
        pendingTask = nil
        pendingDiveIDs = []
        pendingFullRepublish = false
    }

    /// Full mirror of all owned dives (import, settings, friends open).
    static func scheduleRepublish(
        ownerProfileID: UUID,
        modelContext: ModelContext,
        debounceNanoseconds: UInt64 = 200_000_000
    ) {
        observedOwnerProfileID = ownerProfileID
        observedModelContext = modelContext
        pendingFullRepublish = true
        pendingDiveIDs = []
        scheduleFlush(debounceNanoseconds: debounceNanoseconds)
    }

    /// Upserts only the given dives (coalesced across rapid edits).
    static func scheduleUpsert(
        diveIDs: Set<UUID>,
        ownerProfileID: UUID,
        modelContext: ModelContext,
        debounceNanoseconds: UInt64 = 200_000_000
    ) {
        guard !diveIDs.isEmpty else { return }
        observedOwnerProfileID = ownerProfileID
        observedModelContext = modelContext
        if !pendingFullRepublish {
            pendingDiveIDs.formUnion(diveIDs)
        }
        scheduleFlush(debounceNanoseconds: debounceNanoseconds)
    }

    private static func handleDidSave(identifiers: Set<PersistentIdentifier>) {
        guard let ownerProfileID = observedOwnerProfileID,
              let modelContext = observedModelContext
        else { return }
        guard !identifiers.isEmpty else { return }

        var models: [any PersistentModel] = []
        models.reserveCapacity(identifiers.count)
        for id in identifiers {
            models.append(modelContext.model(for: id))
        }

        let diveIDs = GoDiveFriendShareAffectedDiveIDs.diveIDs(
            fromModels: models,
            ownerProfileID: ownerProfileID
        )
        scheduleUpsert(
            diveIDs: diveIDs,
            ownerProfileID: ownerProfileID,
            modelContext: modelContext
        )
    }

    private static func handleExplicitChange(diveID: UUID?) {
        guard let ownerProfileID = observedOwnerProfileID,
              let modelContext = observedModelContext
        else { return }

        if let diveID {
            scheduleUpsert(
                diveIDs: [diveID],
                ownerProfileID: ownerProfileID,
                modelContext: modelContext
            )
            return
        }

        scheduleRepublish(ownerProfileID: ownerProfileID, modelContext: modelContext)
    }

    private static func scheduleFlush(debounceNanoseconds: UInt64) {
        pendingTask?.cancel()
        pendingTask = Task {
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled else { return }
            await flushPending()
        }
    }

    private static func flushPending() async {
        guard let ownerProfileID = observedOwnerProfileID,
              let modelContext = observedModelContext
        else { return }

        let fullRepublish = pendingFullRepublish
        let diveIDs = pendingDiveIDs
        pendingFullRepublish = false
        pendingDiveIDs = []

        if fullRepublish {
            await GoDiveSharedDiveProjectionSync.republishAllOwnedDives(
                ownerProfileID: ownerProfileID,
                modelContext: modelContext
            )
            return
        }

        guard !diveIDs.isEmpty else { return }
        guard await GoDiveSharedDiveProjectionSync.shouldPublishProjections() else { return }

        let owned = (try? modelContext.fetch(FetchDescriptor<DiveActivity>()))?
            .filter { $0.ownerProfileID == ownerProfileID && diveIDs.contains($0.id) } ?? []

        for dive in owned {
            await GoDiveSharedDiveProjectionSync.upsertDive(dive, modelContext: modelContext)
        }
    }
}
