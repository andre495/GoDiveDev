import FirebaseAuth
import FirebaseFirestore
import Foundation
import os

/// Two-phase friend-share media publish: thumbnails + Firestore first, content tiers in background.
///
/// Phase one never touches the expensive exports — it uploads stored 256 px preview bytes and
/// checkpoints publish state after **every** item, so an interrupted publish resumes where it
/// stopped instead of re-uploading. Content jobs carry only a Photos identifier; the queue exports
/// (4096 px JPEG / 1080p MP4) lazily and patches Firestore when each object lands.
enum GoDiveSharedMediaUpload: Sendable {
    private static let log = Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "FriendShareMediaUpload")
    nonisolated private static let maxConcurrentContentUploads = 2

    struct ContentUploadJob: Sendable {
        var mediaID: UUID
        var kind: FriendSharedMediaKind
        var photosLocalIdentifier: String
    }

    @MainActor
    static func clearActivityMedia(ownerUID: String, activityID: UUID) async {
        await GoDiveSharedMediaStorage.deleteAllActivityMedia(ownerUID: ownerUID, activityID: activityID)
        GoDiveSharedMediaPublishState.clearActivity(ownerUID: ownerUID, activityID: activityID)
        await GoDiveSharedMediaUploadQueue.shared.cancel(activityID: activityID)
    }

    @MainActor
    static func uploadMediaItems(
        activityID: UUID,
        on dive: DiveActivity,
        ownerUID: String,
        selectedMediaIDs: Set<UUID> = [],
        restrictsToExplicitSelection: Bool = false,
        userDefaults: UserDefaults = .standard
    ) async -> [GoDiveSharedDiveProjectionMapping.MediaItemSnapshot] {
        let sorted = DiveActivityMediaPresentation.sortedPhotos(on: dive)
        let featuredID = DiveActivityMediaPresentation.featuredPhotoID(on: dive)
        return await publishPhaseOne(
            activityID: activityID,
            sortedMedia: sorted,
            featuredID: featuredID,
            ownerUID: ownerUID,
            selectedMediaIDs: selectedMediaIDs,
            restrictsToExplicitSelection: restrictsToExplicitSelection,
            userDefaults: userDefaults
        )
    }

    @MainActor
    static func uploadMediaItems(
        activityID: UUID,
        on snorkel: SnorkelActivity,
        ownerUID: String,
        selectedMediaIDs: Set<UUID> = [],
        restrictsToExplicitSelection: Bool = false,
        userDefaults: UserDefaults = .standard
    ) async -> [GoDiveSharedDiveProjectionMapping.MediaItemSnapshot] {
        let sorted = SnorkelActivityMediaPresentation.sortedPhotos(snorkel.mediaPhotos)
        let featuredID = SnorkelActivityMediaPresentation.featuredPhotoID(on: snorkel)
        return await publishPhaseOne(
            activityID: activityID,
            sortedMedia: sorted,
            featuredID: featuredID,
            ownerUID: ownerUID,
            selectedMediaIDs: selectedMediaIDs,
            restrictsToExplicitSelection: restrictsToExplicitSelection,
            userDefaults: userDefaults
        )
    }

    @MainActor
    private static func publishPhaseOne<T: ActivityOverviewGalleryMedia>(
        activityID: UUID,
        sortedMedia: [T],
        featuredID: UUID?,
        ownerUID: String,
        selectedMediaIDs: Set<UUID>,
        restrictsToExplicitSelection: Bool,
        userDefaults: UserDefaults
    ) async -> [GoDiveSharedDiveProjectionMapping.MediaItemSnapshot] {
        let galleryMedia: [T]
        if restrictsToExplicitSelection {
            guard !selectedMediaIDs.isEmpty else {
                await clearActivityMedia(ownerUID: ownerUID, activityID: activityID)
                return []
            }
            galleryMedia = sortedMedia.filter { selectedMediaIDs.contains($0.id) }
        } else {
            galleryMedia = sortedMedia
        }
        let candidates = galleryMedia.map { GoDiveSharedMediaSelection.shareCandidate(from: $0) }
        let selected = GoDiveSharedMediaSelection.filteredForShare(galleryMedia)
        let trimSummary = GoDiveSharedMediaSelection.capTrimSummary(
            candidates: candidates,
            shared: selected.map { GoDiveSharedMediaSelection.shareCandidate(from: $0) }
        )
        if let trimNotice = GoDiveSharedMediaSelection.trimNoticeMessage(trimSummary) {
            log.info("Friend share media capped for activity \(activityID.uuidString, privacy: .private): \(trimNotice, privacy: .public)")
        }
        let uploadOrder = GoDiveSharedMediaSelection.uploadOrder(selected: selected, featuredID: featuredID)
        let currentIDs = Set(uploadOrder.map { $0.id.uuidString })

        // A still-running content phase for an older publish of this activity would race the
        // incremental checkpoints below.
        await GoDiveSharedMediaUploadQueue.shared.cancel(activityID: activityID)

        let previous = GoDiveSharedMediaPublishState.loadActivity(ownerUID: ownerUID, activityID: activityID)
        let removedIDs = GoDiveSharedMediaPublishState.removedMediaIDs(
            previous: previous,
            currentMediaIDs: currentIDs
        )
        for removedID in removedIDs {
            guard let uuid = UUID(uuidString: removedID) else { continue }
            await GoDiveSharedMediaStorage.deleteMediaItem(
                ownerUID: ownerUID,
                activityID: activityID,
                mediaID: uuid
            )
        }

        // Cached records for items not yet re-processed — kept in every checkpoint so an
        // interrupted publish never loses previously uploaded URLs.
        let removedSet = Set(removedIDs)
        var pendingPrevious = previous.items.filter { !removedSet.contains($0.mediaID) }

        var records: [GoDiveSharedMediaPublishState.PublishedMediaRecord] = []
        records.reserveCapacity(uploadOrder.count)
        var contentJobs: [ContentUploadJob] = []

        for media in uploadOrder {
            let mediaIDString = media.id.uuidString
            pendingPrevious.removeAll { $0.mediaID == mediaIDString }

            let sourceFingerprint = GoDiveSharedMediaPublishState.sourceFingerprint(
                mediaKind: media.mediaKind,
                photosLocalIdentifier: media.photosLocalIdentifier,
                capturedAt: media.capturedAt,
                sortOrder: media.sortOrder
            )
            let kind: FriendSharedMediaKind = media.resolvedMediaKind == .video ? .video : .photo

            if let cached = GoDiveSharedMediaPublishState.record(for: media.id, in: previous),
               cached.sourceFingerprint == sourceFingerprint,
               !cached.thumbnailURL.isEmpty {
                records.append(cached)
            } else {
                guard let thumbnail = await GoDiveSharedMediaExport.exportThumbnailJPEG(for: media),
                      let thumbnailURL = await GoDiveSharedMediaStorage.uploadTier(
                          ownerUID: ownerUID,
                          activityID: activityID,
                          mediaID: media.id,
                          tier: .thumb,
                          data: thumbnail
                      )
                else { continue }

                records.append(
                    GoDiveSharedMediaPublishState.PublishedMediaRecord(
                        mediaID: mediaIDString,
                        kind: kind.rawValue,
                        sourceFingerprint: sourceFingerprint,
                        exportFingerprint: nil,
                        thumbnailURL: thumbnailURL,
                        contentURL: nil,
                        width: nil,
                        height: nil,
                        durationSeconds: nil,
                        contentBytes: nil
                    )
                )
            }

            GoDiveSharedMediaPublishState.saveActivity(
                ownerUID: ownerUID,
                activityID: activityID,
                record: .init(items: records + pendingPrevious)
            )

            if records.last?.mediaID == mediaIDString, records.last?.contentURL == nil {
                contentJobs.append(
                    ContentUploadJob(
                        mediaID: media.id,
                        kind: kind,
                        photosLocalIdentifier: media.photosLocalIdentifier
                    )
                )
            }
        }

        GoDiveSharedMediaPublishState.saveActivity(
            ownerUID: ownerUID,
            activityID: activityID,
            record: .init(items: records)
        )

        if !contentJobs.isEmpty {
            await GoDiveSharedMediaUploadQueue.shared.scheduleContentPhase(
                ownerUID: ownerUID,
                activityID: activityID,
                jobs: contentJobs,
                userDefaults: userDefaults
            )
        }

        return records.map { $0.snapshot() }
    }

    @MainActor
    static func resumeIncompleteContentPhase(
        ownerUID: String,
        activityID: UUID,
        userDefaults: UserDefaults = .standard
    ) async {
        let jobs = pendingContentJobs(ownerUID: ownerUID, activityID: activityID)
        guard !jobs.isEmpty else { return }
        await GoDiveSharedMediaUploadQueue.shared.scheduleContentPhase(
            ownerUID: ownerUID,
            activityID: activityID,
            jobs: jobs,
            userDefaults: userDefaults
        )
    }

    nonisolated static func pendingContentJobs(
        ownerUID: String,
        activityID: UUID
    ) -> [ContentUploadJob] {
        let record = GoDiveSharedMediaPublishState.loadActivityRecord(
            ownerUID: ownerUID,
            activityID: activityID
        )
        var jobs: [ContentUploadJob] = []
        jobs.reserveCapacity(record.items.count)
        for item in record.items {
            guard !item.thumbnailURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  (item.contentURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let mediaID = UUID(uuidString: item.mediaID),
                  let localID = GoDiveSharedMediaPublishState.photosLocalIdentifier(
                    fromSourceFingerprint: item.sourceFingerprint
                  )
            else { continue }
            let kind = FriendSharedMediaKind(rawValue: item.kind) ?? .photo
            jobs.append(
                ContentUploadJob(
                    mediaID: mediaID,
                    kind: kind,
                    photosLocalIdentifier: localID
                )
            )
        }
        return jobs
    }

    @MainActor
    static func allowsContentUpload(userDefaults: UserDefaults = .standard) -> Bool {
        AppNetworkConnectivityPresentation.allowsFriendShareContentUpload(
            isConnected: AppNetworkConnectivitySnapshot.shared.allowsCloudMediaFetch,
            usesWiFi: AppNetworkConnectivitySnapshot.shared.usesWiFiInterface,
            wifiOnly: AppUserSettings.shareMediaOnWiFiOnly(userDefaults: userDefaults)
        )
    }

    @MainActor
    static func performContentPhase(
        ownerUID: String,
        activityID: UUID,
        jobs: [ContentUploadJob],
        userDefaults: UserDefaults
    ) async {
        guard allowsContentUpload(userDefaults: userDefaults) else {
            GoDiveBuddyShareBackgroundUpload.scheduleProcessingIfNeeded()
            return
        }

        var patchedAnyRecord = false

        await withTaskGroup(of: GoDiveSharedMediaPublishState.PublishedMediaRecord?.self) { group in
            var iterator = jobs.makeIterator()
            var inFlight = 0

            func enqueueNext() {
                guard !Task.isCancelled,
                      inFlight < maxConcurrentContentUploads,
                      let job = iterator.next()
                else { return }
                inFlight += 1
                group.addTask { @MainActor in
                    await uploadContentJob(job, ownerUID: ownerUID, activityID: activityID)
                }
            }

            for _ in 0 ..< min(maxConcurrentContentUploads, jobs.count) {
                enqueueNext()
            }

            for await record in group {
                inFlight -= 1
                // Checkpoint each completed object immediately — a killed app or cancelled phase
                // never loses finished uploads.
                if let record {
                    var state = GoDiveSharedMediaPublishState.loadActivity(
                        ownerUID: ownerUID,
                        activityID: activityID
                    )
                    if let index = state.items.firstIndex(where: { $0.mediaID == record.mediaID }) {
                        state.items[index] = record
                        GoDiveSharedMediaPublishState.saveActivity(
                            ownerUID: ownerUID,
                            activityID: activityID,
                            record: state
                        )
                        patchedAnyRecord = true
                    }
                }
                enqueueNext()
            }
        }

        guard patchedAnyRecord, !Task.isCancelled else { return }
        let finalState = GoDiveSharedMediaPublishState.loadActivity(
            ownerUID: ownerUID,
            activityID: activityID
        )
        await patchFirestoreMediaItems(
            ownerUID: ownerUID,
            activityID: activityID,
            records: finalState.items
        )
    }

    @MainActor
    static func uploadContentJob(
        _ job: ContentUploadJob,
        ownerUID: String,
        activityID: UUID
    ) async -> GoDiveSharedMediaPublishState.PublishedMediaRecord? {
        let contentURL: String?
        let contentBytes: Int?
        var width: Int?
        var height: Int?
        var durationSeconds: Double?
        let exportFingerprint: String

        switch job.kind {
        case .photo:
            guard let jpeg = await GoDiveSharedMediaExport.exportPhotoContentJPEG(
                photosLocalIdentifier: job.photosLocalIdentifier
            ) else { return nil }
            contentURL = await GoDiveSharedMediaStorage.uploadTier(
                ownerUID: ownerUID,
                activityID: activityID,
                mediaID: job.mediaID,
                tier: .photo,
                data: jpeg
            )
            contentBytes = contentURL == nil ? nil : jpeg.count
            let dimensions = GoDiveSharedMediaExport.jpegDimensions(jpeg)
            width = dimensions?.width
            height = dimensions?.height
            exportFingerprint = GoDiveSharedMediaPublishState.sha256Hex(jpeg)
        case .video:
            guard let mp4 = await GoDiveSharedMediaExport.exportSharedVideoMP4(
                photosLocalIdentifier: job.photosLocalIdentifier
            ) else { return nil }
            contentURL = await GoDiveSharedMediaStorage.uploadTier(
                ownerUID: ownerUID,
                activityID: activityID,
                mediaID: job.mediaID,
                tier: .video,
                data: mp4
            )
            contentBytes = contentURL == nil ? nil : mp4.count
            width = 1920
            height = 1080
            durationSeconds = GoDiveSharedMediaLimits.maxSharedVideoDurationSeconds
            exportFingerprint = GoDiveSharedMediaPublishState.sha256Hex(mp4)
        }

        guard let contentURL else { return nil }

        let activity = GoDiveSharedMediaPublishState.loadActivity(ownerUID: ownerUID, activityID: activityID)
        guard var existing = GoDiveSharedMediaPublishState.record(for: job.mediaID, in: activity) else {
            return nil
        }
        existing.contentURL = contentURL
        existing.contentBytes = contentBytes
        existing.width = width ?? existing.width
        existing.height = height ?? existing.height
        existing.durationSeconds = durationSeconds ?? existing.durationSeconds
        existing.exportFingerprint = exportFingerprint
        return existing
    }

    @MainActor
    static func patchFirestoreMediaItems(
        ownerUID: String,
        activityID: UUID,
        records: [GoDiveSharedMediaPublishState.PublishedMediaRecord]
    ) async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard Auth.auth().currentUser?.uid == ownerUID else { return }

        let rows = records.map { $0.snapshot() }.map(GoDiveSharedDiveProjectionMapping.mediaItemFirestoreRow)
        do {
            try await Firestore.firestore()
                .collection("users")
                .document(ownerUID)
                .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
                .document(activityID.uuidString)
                .setData(
                    [
                        "mediaItems": rows,
                        "updatedAt": Date(),
                    ],
                    merge: true
                )
        } catch {
            log.error("Shared media Firestore patch failed: \(String(describing: error), privacy: .private)")
        }
    }
}

/// Serializes background content-tier uploads per activity.
actor GoDiveSharedMediaUploadQueue {
    static let shared = GoDiveSharedMediaUploadQueue()

    private var tasks: [String: Task<Void, Never>] = [:]

    func cancel(activityID: UUID) {
        let key = activityID.uuidString
        tasks[key]?.cancel()
        tasks[key] = nil
        Task { @MainActor in
            await notifyIdleStateIfNeeded()
        }
    }

    func scheduleContentPhase(
        ownerUID: String,
        activityID: UUID,
        jobs: [GoDiveSharedMediaUpload.ContentUploadJob],
        userDefaults: UserDefaults
    ) {
        guard !jobs.isEmpty else { return }
        let key = activityID.uuidString
        tasks[key]?.cancel()
        Task { @MainActor in
            GoDiveBuddyShareBackgroundUpload.beginBackgroundExecution()
        }
        tasks[key] = Task {
            await GoDiveSharedMediaUpload.performContentPhase(
                ownerUID: ownerUID,
                activityID: activityID,
                jobs: jobs,
                userDefaults: userDefaults
            )
            await GoDiveSharedMediaUploadQueue.shared.releaseTask(forKey: key)
        }
    }

    func hasPendingUpload(for activityID: UUID) -> Bool {
        tasks[activityID.uuidString] != nil
    }

    func hasAnyPendingUpload() -> Bool {
        !tasks.isEmpty
    }

    private func releaseTask(forKey key: String) {
        tasks[key] = nil
        Task { @MainActor in
            await notifyIdleStateIfNeeded()
        }
    }

    @MainActor
    private func notifyIdleStateIfNeeded() async {
        guard let ownerUID = Auth.auth().currentUser?.uid,
              let ownerProfileID = AppLaunchSessionRestorePresentation.loadPersistedProfileID()
        else { return }
        await GoDiveBuddyShareBackgroundUpload.refreshBackgroundExecutionIdleState(
            ownerProfileID: ownerProfileID,
            ownerUID: ownerUID
        )
    }
}
