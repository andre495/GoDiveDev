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
        modelContext: ModelContext
    ) async -> Outcome {
        await attachMatchingLibraryMedia(
            activities: [activity],
            ownerProfileID: ownerProfileID,
            modelContext: modelContext
        )
    }

    @MainActor
    static func attachMatchingLibraryMedia(
        activities: [DiveActivity],
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) async -> Outcome {
        guard AppUserSettings.autoUploadMediaToActivities else { return emptyOutcome }
        return await attachMatchingLibraryMedia(
            activities: activities,
            ownerProfileID: ownerProfileID,
            modelContext: modelContext,
            onProgress: nil
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

        do {
            let dives = try DiveActivityOwnership.activities(forOwnerProfileID: ownerProfileID, modelContext: modelContext)
            guard !dives.isEmpty else {
                reportProgress(completed: 1, total: 1, stage: DiveLibraryMediaAutoAttachPresentation.stageNoDives, onProgress: onProgress)
                return emptyOutcome
            }
            return await attachMatchingLibraryMedia(
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
    private static func attachMatchingLibraryMedia(
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

            let window = DiveActivityMediaAttachWindow.window(for: activity)
            let assets = fetchAssets(in: window)

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
                if linkedIdentifiers.contains(identifier) {
                    skippedAlreadyLinked += 1
                    continue
                }
                guard asset.creationDate != nil else {
                    skippedNoCaptureDate += 1
                    continue
                }

                do {
                    let loaded = try await DiveLibraryMediaAssetLoader.load(from: asset)
                    if Task.isCancelled { break }
                    _ = try DiveActivityMediaStorage.addMedia(
                        loaded.payload,
                        capturedAt: loaded.capturedAt,
                        photosLocalIdentifier: identifier,
                        to: activity,
                        modelContext: modelContext
                    )
                    linkedIdentifiers.insert(identifier)
                    attachedCount += 1
                } catch {
                    continue
                }
            }

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
    @MainActor
    static func attachAfterDivePersisted(
        _ activity: DiveActivity,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) async {
        _ = await DiveLibraryMediaAutoAttach.attachMatchingLibraryMedia(
            for: activity,
            ownerProfileID: ownerProfileID,
            modelContext: modelContext
        )
    }

    @MainActor
    static func attachAfterDivesPersisted(
        _ activities: [DiveActivity],
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) async {
        guard !activities.isEmpty else { return }
        _ = await DiveLibraryMediaAutoAttach.attachMatchingLibraryMedia(
            activities: activities,
            ownerProfileID: ownerProfileID,
            modelContext: modelContext
        )
    }
}
