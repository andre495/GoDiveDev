import FirebaseAuth
import Foundation
import SwiftData

/// Debounced upsert / republish of friend-visible dive projections after local log changes.
///
/// The debounce timer and the actual publish are **separate** tasks: rescheduling only resets the
/// timer. A publish that is already flushing (thumb uploads + Firestore writes can take many
/// seconds) is never cancelled mid-write — new work queues behind it and drains afterwards.
@MainActor
enum GoDiveFriendShareRefreshCoordinator {
    private static var pendingTask: Task<Void, Never>?
    private static var drainTask: Task<Void, Never>?
    private static var pendingDiveIDs: Set<UUID> = []
    private static var pendingFullRepublish = false
    private static var didSaveObserver: NSObjectProtocol?
    private static var explicitChangeObserver: NSObjectProtocol?
    private static var deferredMediaUploadObserver: NSObjectProtocol?
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

        deferredMediaUploadObserver = NotificationCenter.default.addObserver(
            forName: .goDiveSharedMediaContentUploadDue,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                guard let ownerProfileID = observedOwnerProfileID,
                      let modelContext = observedModelContext
                else { return }
                await GoDiveBuddyShareBackgroundUpload.resumePendingWork(
                    ownerProfileID: ownerProfileID,
                    modelContext: modelContext
                )
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
        if let deferredMediaUploadObserver {
            NotificationCenter.default.removeObserver(deferredMediaUploadObserver)
            self.deferredMediaUploadObserver = nil
        }
        observedOwnerProfileID = nil
        observedModelContext = nil
        pendingTask?.cancel()
        pendingTask = nil
        drainTask?.cancel()
        drainTask = nil
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
        GoDiveBuddySharePendingWorkStore.markFullRepublishPending(ownerProfileID: ownerProfileID)
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
            GoDiveBuddySharePendingWorkStore.addPendingUpserts(
                ownerProfileID: ownerProfileID,
                activityIDs: diveIDs
            )
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
        // Only the debounce timer restarts — an in-flight drain keeps running and picks up the
        // newly queued work on its next loop pass.
        pendingTask?.cancel()
        pendingTask = Task {
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled else { return }
            startDrainIfNeeded()
        }
    }

    private static var drainGeneration = 0

    private static func startDrainIfNeeded() {
        guard drainTask == nil else { return }
        drainGeneration += 1
        let generation = drainGeneration
        drainTask = Task {
            while pendingFullRepublish || !pendingDiveIDs.isEmpty {
                guard !Task.isCancelled else { break }
                await flushPending()
            }
            if drainGeneration == generation {
                drainTask = nil
            }
        }
    }

    private static func flushPending() async {
        guard let ownerProfileID = observedOwnerProfileID,
              let modelContext = observedModelContext
        else {
            pendingFullRepublish = false
            pendingDiveIDs = []
            return
        }

        let fullRepublish = pendingFullRepublish
        let diveIDs = pendingDiveIDs
        pendingFullRepublish = false
        pendingDiveIDs = []

        if fullRepublish {
            GoDiveBuddyShareBackgroundUpload.beginBackgroundExecution()
            await GoDiveSharedDiveProjectionSync.republishAllOwnedDives(
                ownerProfileID: ownerProfileID,
                modelContext: modelContext
            )
            GoDiveBuddySharePendingWorkStore.clearFullRepublishPending(ownerProfileID: ownerProfileID)
            if let ownerUID = Auth.auth().currentUser?.uid {
                await GoDiveBuddyShareBackgroundUpload.refreshBackgroundExecutionIdleState(
                    ownerProfileID: ownerProfileID,
                    ownerUID: ownerUID
                )
            }
            return
        }

        guard !diveIDs.isEmpty else { return }

        GoDiveBuddyShareBackgroundUpload.beginBackgroundExecution()

        let owned = (try? modelContext.fetch(FetchDescriptor<DiveActivity>()))?
            .filter { $0.ownerProfileID == ownerProfileID && diveIDs.contains($0.id) } ?? []

        var completedUpserts: Set<UUID> = []

        for dive in owned {
            let upserted = await GoDiveSharedDiveProjectionSync.upsertDive(dive, modelContext: modelContext)
            if upserted {
                await GoDiveSharedMediaUploadQueue.shared.awaitPendingUpload(for: dive.id)
                completedUpserts.insert(dive.id)
            }
        }

        let ownedSnorkels = (try? modelContext.fetch(FetchDescriptor<SnorkelActivity>()))?
            .filter { $0.ownerProfileID == ownerProfileID && diveIDs.contains($0.id) } ?? []

        for snorkel in ownedSnorkels {
            let upserted = await GoDiveSharedDiveProjectionSync.upsertSnorkel(snorkel, modelContext: modelContext)
            if upserted {
                await GoDiveSharedMediaUploadQueue.shared.awaitPendingUpload(for: snorkel.id)
                completedUpserts.insert(snorkel.id)
            }
        }

        GoDiveBuddySharePendingWorkStore.clearPendingUpserts(
            ownerProfileID: ownerProfileID,
            activityIDs: completedUpserts
        )
        if let ownerUID = Auth.auth().currentUser?.uid {
            await GoDiveBuddyShareBackgroundUpload.refreshBackgroundExecutionIdleState(
                ownerProfileID: ownerProfileID,
                ownerUID: ownerUID
            )
        }
    }
}
