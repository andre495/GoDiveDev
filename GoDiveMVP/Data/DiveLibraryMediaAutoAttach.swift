import Foundation
import SwiftData
#if canImport(Photos)
import Photos
#endif

/// Attaches Apple Photos library items whose capture time falls within a dive window.
enum DiveLibraryMediaAutoAttach: Sendable {

    struct Outcome: Sendable, Equatable {
        var attachedCount: Int
        var skippedAlreadyLinked: Int
        var skippedNoCaptureDate: Int
        var authorizationDenied: Bool
    }

    struct ProgressUpdate: Sendable, Equatable {
        var completed: Int
        var total: Int
        var stage: String
    }

    typealias ProgressHandler = @MainActor (_ update: ProgressUpdate) -> Void

    static let emptyOutcome = Outcome(
        attachedCount: 0,
        skippedAlreadyLinked: 0,
        skippedNoCaptureDate: 0,
        authorizationDenied: false
    )

    @MainActor
    static func attachMatchingLibraryMedia(
        for activity: DiveActivity,
        ownerProfileID: UUID,
        modelContext: ModelContext,
        requiresAutoUploadSetting: Bool = true
    ) async -> Outcome {
        await attachMatchingLibraryMedia(
            activities: [activity],
            ownerProfileID: ownerProfileID,
            modelContext: modelContext,
            requiresAutoUploadSetting: requiresAutoUploadSetting
        )
    }

    @MainActor
    static func attachMatchingLibraryMedia(
        activities: [DiveActivity],
        ownerProfileID: UUID,
        modelContext: ModelContext,
        onProgress: ProgressHandler? = nil,
        requiresAutoUploadSetting: Bool = true
    ) async -> Outcome {
        if requiresAutoUploadSetting {
            guard AppUserSettings.autoUploadMediaToActivities else { return emptyOutcome }
        }
        return await performAttachMatchingLibraryMedia(
            activities: activities,
            ownerProfileID: ownerProfileID,
            modelContext: modelContext,
            onProgress: onProgress
        )
    }

    /// Scans the library for all owner dives (used when enabling auto-upload in **Settings**).
    @MainActor
    static func attachMatchingLibraryMediaForAllOwnerDives(
        ownerProfileID: UUID,
        modelContext: ModelContext,
        onProgress: ProgressHandler? = nil
    ) async -> Outcome {
        guard AppUserSettings.autoUploadMediaToActivities else { return emptyOutcome }

        // Always surface the Photos prompt when enabling auto-upload, even before any dives exist.
        reportProgress(completed: 0, total: 1, stage: DiveLibraryMediaAutoAttachPresentation.stageRequestingAccess, onProgress: onProgress)
        guard await requestPhotoLibraryReadAccess() else {
            return Outcome(
                attachedCount: 0,
                skippedAlreadyLinked: 0,
                skippedNoCaptureDate: 0,
                authorizationDenied: true
            )
        }

        do {
            let dives = try DiveActivityOwnership.activities(forOwnerProfileID: ownerProfileID, modelContext: modelContext)
            guard !dives.isEmpty else {
                reportProgress(completed: 1, total: 1, stage: DiveLibraryMediaAutoAttachPresentation.stageNoDives, onProgress: onProgress)
                return emptyOutcome
            }
            return await performAttachMatchingLibraryMedia(
                activities: dives,
                ownerProfileID: ownerProfileID,
                modelContext: modelContext,
                onProgress: onProgress
            )
        } catch {
            reportProgress(completed: 1, total: 1, stage: DiveLibraryMediaAutoAttachPresentation.stageLoadLogFailed, onProgress: onProgress)
            return emptyOutcome
        }
    }

    @MainActor
    private static func performAttachMatchingLibraryMedia(
        activities: [DiveActivity],
        ownerProfileID: UUID,
        modelContext: ModelContext,
        onProgress: ProgressHandler?
    ) async -> Outcome {
        guard !activities.isEmpty else { return emptyOutcome }

        if onProgress != nil {
            reportProgress(completed: 0, total: 1, stage: DiveLibraryMediaAutoAttachPresentation.stageRequestingAccess, onProgress: onProgress)
        }

        guard await requestPhotoLibraryReadAccess() else {
            return Outcome(
                attachedCount: 0,
                skippedAlreadyLinked: 0,
                skippedNoCaptureDate: 0,
                authorizationDenied: true
            )
        }

        #if canImport(Photos)
        guard !Task.isCancelled else { return emptyOutcome }

        await DiveActivityTimeZoneResolution.resolveMissingOffsets(for: activities)

        var linkedIdentifiers: Set<String>
        do {
            linkedIdentifiers = try existingPhotosLocalIdentifiers(
                ownerProfileID: ownerProfileID,
                modelContext: modelContext
            )
        } catch {
            return emptyOutcome
        }

        let divesNewestFirst = activities.sorted { $0.startTime > $1.startTime }
        let diveCount = divesNewestFirst.count
        var attachedCount = 0
        var skippedAlreadyLinked = 0
        var skippedNoCaptureDate = 0

        for (diveIndex, activity) in divesNewestFirst.enumerated() {
            if Task.isCancelled { break }

            if onProgress != nil {
                reportProgress(
                    completed: diveIndex,
                    total: diveCount,
                    stage: DiveLibraryMediaAutoAttachPresentation.stageCheckingDive(
                        diveIndex: diveIndex + 1,
                        diveCount: diveCount
                    ),
                    onProgress: onProgress
                )
            }

            let preciseWindow = DiveActivityMediaAttachWindow.window(for: activity)
            let fetchWindow = DiveActivityMediaAttachWindow.photoLibraryFetchWindow(for: activity)
            let timeZone = DiveActivityMediaAttachWindow.resolvedTimeZone(for: activity)
            // Recover camera media (e.g. GoPro) that stored local wall-clock time in a UTC field.
            let diveLocalOffsetSeconds = timeZone.secondsFromGMT(for: activity.startTime)
            let assets = fetchAssets(in: fetchWindow)

            DiveLibraryMediaAttachDebug.diveStart(
                index: diveIndex + 1,
                total: diveCount,
                diveStartTime: activity.startTime,
                timeZone: timeZone,
                window: preciseWindow,
                fetchWindow: fetchWindow,
                fetchedAssetCount: assets.count
            )

            var diveAttached = 0
            var diveSkippedOutside = 0
            var diveSkippedNoCreation = 0

            for (assetIndex, asset) in assets.enumerated() {
                if Task.isCancelled { break }

                if onProgress != nil, !assets.isEmpty {
                    reportProgress(
                        completed: diveIndex,
                        total: diveCount,
                        stage: DiveLibraryMediaAutoAttachPresentation.stageMatchingPhotosInDive(
                            processed: assetIndex + 1,
                            total: assets.count
                        ),
                        onProgress: onProgress
                    )
                }

                let identifier = asset.localIdentifier
                let isVideo = asset.mediaType == .video
                let mediaTypeLabel = isVideo ? "video" : "image"

                if linkedIdentifiers.contains(identifier) {
                    skippedAlreadyLinked += 1
                    DiveLibraryMediaAttachDebug.asset(
                        localIdentifier: identifier,
                        mediaTypeLabel: mediaTypeLabel,
                        creationDate: asset.creationDate,
                        capturedAt: nil,
                        timeZone: timeZone,
                        decision: .alreadyLinked
                    )
                    continue
                }
                guard let creationDate = asset.creationDate else {
                    skippedNoCaptureDate += 1
                    diveSkippedNoCreation += 1
                    DiveLibraryMediaAttachDebug.asset(
                        localIdentifier: identifier,
                        mediaTypeLabel: mediaTypeLabel,
                        creationDate: nil,
                        capturedAt: nil,
                        timeZone: timeZone,
                        decision: .missingCreationDate
                    )
                    continue
                }

                // Offset recovery only for video (QuickTime stores camera local time as UTC, e.g. GoPro);
                // photo `creationDate` is generally correctly zoned, so keep the strict test to avoid
                // attaching same-trip photos to a neighbouring dive.
                guard preciseWindow.shouldAttachAsset(
                    creationDate: creationDate,
                    diveLocalOffsetSeconds: isVideo ? diveLocalOffsetSeconds : nil
                ) else {
                    diveSkippedOutside += 1
                    DiveLibraryMediaAttachDebug.asset(
                        localIdentifier: identifier,
                        mediaTypeLabel: mediaTypeLabel,
                        creationDate: creationDate,
                        capturedAt: nil,
                        timeZone: timeZone,
                        decision: .outsideWindow
                    )
                    continue
                }

                do {
                    // Store a pointer to the Photos asset (no exported file / inline bytes); pixels and frames
                    // load on demand via `DiveMediaReferenceLoader`. This also sidesteps iCloud export failures.
                    _ = try DiveActivityMediaStorage.addLibraryReference(
                        localIdentifier: identifier,
                        mediaKind: isVideo ? .video : .image,
                        capturedAt: creationDate,
                        to: activity,
                        modelContext: modelContext
                    )
                    linkedIdentifiers.insert(identifier)
                    attachedCount += 1
                    diveAttached += 1
                    DiveLibraryMediaAttachDebug.asset(
                        localIdentifier: identifier,
                        mediaTypeLabel: mediaTypeLabel,
                        creationDate: creationDate,
                        capturedAt: creationDate,
                        timeZone: timeZone,
                        decision: .matched
                    )
                } catch {
                    DiveLibraryMediaAttachDebug.asset(
                        localIdentifier: identifier,
                        mediaTypeLabel: mediaTypeLabel,
                        creationDate: creationDate,
                        capturedAt: nil,
                        timeZone: timeZone,
                        decision: .loadFailed,
                        detail: String(describing: error)
                    )
                    continue
                }
            }

            DiveLibraryMediaAttachDebug.diveSummary(
                index: diveIndex + 1,
                attached: diveAttached,
                skippedAlreadyLinked: skippedAlreadyLinked,
                skippedOutsideWindow: diveSkippedOutside,
                skippedNoCreationDate: diveSkippedNoCreation
            )

            if onProgress != nil {
                await Task.yield()
            }
        }

        if onProgress != nil {
            reportProgress(
                completed: diveCount,
                total: diveCount,
                stage: DiveLibraryMediaAutoAttachPresentation.stageCheckingDive(
                    diveIndex: diveCount,
                    diveCount: diveCount
                ),
                onProgress: onProgress
            )
        }

        return Outcome(
            attachedCount: attachedCount,
            skippedAlreadyLinked: skippedAlreadyLinked,
            skippedNoCaptureDate: skippedNoCaptureDate,
            authorizationDenied: false
        )
        #else
        _ = activities
        _ = ownerProfileID
        _ = modelContext
        _ = onProgress
        return emptyOutcome
        #endif
    }

    @MainActor
    private static func reportProgress(
        completed: Int,
        total: Int,
        stage: String,
        onProgress: ProgressHandler?
    ) {
        onProgress?(ProgressUpdate(completed: completed, total: total, stage: stage))
    }

    @MainActor
    static func requestPhotoLibraryReadAccess() async -> Bool {
        #if canImport(Photos)
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
        #else
        false
        #endif
    }

    /// Whether to prompt for Photos access (e.g. on profile setup): only when auto-upload is on and the user has not chosen yet.
    nonisolated static func shouldRequestPhotoAccessForAutoUpload(
        autoUploadEnabled: Bool,
        authorizationResolved: Bool
    ) -> Bool {
        autoUploadEnabled && !authorizationResolved
    }

    /// **`true`** when the user has already made a Photos access choice (granted or denied).
    @MainActor
    static var hasResolvedPhotoLibraryAuthorization: Bool {
        #if canImport(Photos)
        return PHPhotoLibrary.authorizationStatus(for: .readWrite) != .notDetermined
        #else
        return true
        #endif
    }

    #if canImport(Photos)
    @MainActor
    private static func fetchAssets(in window: DiveActivityMediaAttachWindow) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.includeHiddenAssets = false
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            window.inclusiveStart as NSDate,
            window.inclusiveEnd as NSDate
        )
        var assets: [PHAsset] = []
        for mediaType in [PHAssetMediaType.image, .video] {
            let result = PHAsset.fetchAssets(with: mediaType, options: options)
            assets.reserveCapacity(assets.count + result.count)
            result.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
        }
        return assets
    }
    #endif

    static func existingPhotosLocalIdentifiers(
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> Set<String> {
        let dives = try DiveActivityOwnership.activities(forOwnerProfileID: ownerProfileID, modelContext: modelContext)
        var identifiers = Set<String>()
        for dive in dives {
            for photo in dive.mediaPhotos {
                let trimmed = photo.photosLocalIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    identifiers.insert(trimmed)
                }
            }
        }
        return identifiers
    }
}

/// Runs library auto-attach after dives are saved (import / manual).
enum DiveLibraryMediaAutoAttachScheduler: Sendable {
    /// **`attachMediaFromPhotoLibrary`**: pass **`nil`** to honor the global **`autoUploadMediaToActivities`** setting
    /// (manual entry, default FIT path), or an explicit **`Bool`** to override it for this import (e.g. the FIT
    /// import options sheet) — **`true`** forces the attach regardless of the setting, **`false`** skips it.
    @MainActor
    static func attachAfterDivePersisted(
        _ activity: DiveActivity,
        ownerProfileID: UUID,
        modelContext: ModelContext,
        attachMediaFromPhotoLibrary: Bool? = nil
    ) async {
        let shouldAttach = attachMediaFromPhotoLibrary ?? AppUserSettings.autoUploadMediaToActivities
        guard shouldAttach else { return }
        _ = await DiveLibraryMediaAutoAttach.attachMatchingLibraryMedia(
            for: activity,
            ownerProfileID: ownerProfileID,
            modelContext: modelContext,
            requiresAutoUploadSetting: attachMediaFromPhotoLibrary == nil
        )
    }

    @MainActor
    static func attachAfterDivesPersisted(
        _ activities: [DiveActivity],
        ownerProfileID: UUID,
        modelContext: ModelContext,
        attachMediaFromPhotoLibrary: Bool,
        onProgress: DiveLibraryMediaAutoAttach.ProgressHandler? = nil
    ) async {
        guard attachMediaFromPhotoLibrary, !activities.isEmpty else { return }
        _ = await DiveLibraryMediaAutoAttach.attachMatchingLibraryMedia(
            activities: activities,
            ownerProfileID: ownerProfileID,
            modelContext: modelContext,
            onProgress: onProgress,
            requiresAutoUploadSetting: false
        )
    }
}
