import Foundation
import SwiftData
#if canImport(Photos)
import Photos
#endif

enum SnorkelLibraryMediaAutoAttach {

    @MainActor
    static func attachMatchingLibraryMedia(
        for activity: SnorkelActivity,
        ownerProfileID: UUID,
        modelContext: ModelContext,
        requiresAutoUploadSetting: Bool = true
    ) async -> DiveLibraryMediaAutoAttach.Outcome {
        if requiresAutoUploadSetting {
            guard AppUserSettings.autoUploadMediaToActivities else { return DiveLibraryMediaAutoAttach.emptyOutcome }
        }
        #if canImport(Photos)
        guard await DiveLibraryMediaAutoAttach.requestPhotoLibraryReadAccess() else {
            return DiveLibraryMediaAutoAttach.Outcome(
                attachedCount: 0,
                skippedAlreadyLinked: 0,
                skippedNoCaptureDate: 0,
                authorizationDenied: true
            )
        }

        await SnorkelActivityTimeZoneResolution.resolveMissingOffset(for: activity)

        var linkedIdentifiers: Set<String>
        do {
            linkedIdentifiers = try existingPhotosLocalIdentifiers(
                ownerProfileID: ownerProfileID,
                modelContext: modelContext
            )
        } catch {
            return DiveLibraryMediaAutoAttach.emptyOutcome
        }

        let preciseWindow = SnorkelActivityMediaAttachWindow.window(for: activity)
        let fetchWindow = SnorkelActivityMediaAttachWindow.photoLibraryFetchWindow(for: activity)
        let timeZone = SnorkelActivityMediaAttachWindow.resolvedTimeZone(for: activity)
        let localOffsetSeconds = timeZone.secondsFromGMT(for: activity.startTime)
        let assets = fetchAssets(in: fetchWindow)

        var attachedCount = 0
        var skippedAlreadyLinked = 0
        var skippedNoCaptureDate = 0

        for asset in assets {
            let identifier = asset.localIdentifier
            let isVideo = asset.mediaType == .video
            if linkedIdentifiers.contains(identifier) {
                skippedAlreadyLinked += 1
                continue
            }
            guard let creationDate = asset.creationDate else {
                skippedNoCaptureDate += 1
                continue
            }
            guard preciseWindow.shouldAttachAsset(
                creationDate: creationDate,
                diveLocalOffsetSeconds: isVideo ? localOffsetSeconds : nil
            ) else {
                continue
            }
            do {
                _ = try SnorkelActivityMediaStorage.addLibraryReference(
                    localIdentifier: identifier,
                    mediaKind: isVideo ? .video : .image,
                    capturedAt: creationDate,
                    to: activity,
                    modelContext: modelContext
                )
                linkedIdentifiers.insert(identifier)
                attachedCount += 1
            } catch {
                continue
            }
        }

        return DiveLibraryMediaAutoAttach.Outcome(
            attachedCount: attachedCount,
            skippedAlreadyLinked: skippedAlreadyLinked,
            skippedNoCaptureDate: skippedNoCaptureDate,
            authorizationDenied: false
        )
        #else
        _ = activity
        _ = ownerProfileID
        _ = modelContext
        return DiveLibraryMediaAutoAttach.emptyOutcome
        #endif
    }

    static func existingPhotosLocalIdentifiers(
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> Set<String> {
        var identifiers = try DiveLibraryMediaAutoAttach.existingPhotosLocalIdentifiers(
            ownerProfileID: ownerProfileID,
            modelContext: modelContext
        )
        let snorkels = try SnorkelActivityOwnership.activities(forOwnerProfileID: ownerProfileID, modelContext: modelContext)
        for activity in snorkels {
            for photo in activity.mediaPhotos {
                let trimmed = photo.photosLocalIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    identifiers.insert(trimmed)
                }
            }
        }
        return identifiers
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
            result.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
        }
        return assets
    }
    #endif
}

enum SnorkelActivityMediaAttachWindow {

    nonisolated static func window(
        for activity: SnorkelActivity,
        paddingSeconds: TimeInterval = DiveActivityMediaAttachWindow.defaultPaddingSeconds
    ) -> DiveActivityMediaAttachWindow {
        let timeZone = resolvedTimeZone(for: activity)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let anchor = DiveActivityMediaAttachWindow.localStartAnchor(for: activity.startTime, calendar: calendar)
        let durationSeconds = activity.durationMinutes > 0
            ? activity.durationMinutes * 60
            : Int(DiveActivityMediaAttachWindow.defaultUnknownDiveDurationSeconds)
        let padding = Int(paddingSeconds.rounded(.towardZero))

        let inclusiveStart = calendar.date(byAdding: .second, value: -padding, to: anchor)
            ?? anchor.addingTimeInterval(-paddingSeconds)
        let sessionEnd = calendar.date(byAdding: .second, value: durationSeconds, to: anchor)
            ?? anchor.addingTimeInterval(TimeInterval(durationSeconds))
        let inclusiveEnd = calendar.date(byAdding: .second, value: padding, to: sessionEnd)
            ?? sessionEnd.addingTimeInterval(paddingSeconds)

        return DiveActivityMediaAttachWindow(inclusiveStart: inclusiveStart, inclusiveEnd: inclusiveEnd)
    }

    nonisolated static func photoLibraryFetchWindow(
        for activity: SnorkelActivity,
        paddingSeconds: TimeInterval = DiveActivityMediaAttachWindow.defaultPaddingSeconds
    ) -> DiveActivityMediaAttachWindow {
        let precise = window(for: activity, paddingSeconds: paddingSeconds)
        let timeZone = resolvedTimeZone(for: activity)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let localStartDay = calendar.startOfDay(for: precise.inclusiveStart)
        let localEndDay = calendar.startOfDay(for: precise.inclusiveEnd)
        let fetchStart = calendar.date(byAdding: .day, value: -1, to: localStartDay)
            ?? localStartDay.addingTimeInterval(-86_400)
        let fetchEnd = calendar.date(byAdding: .day, value: 1, to: localEndDay)
            ?? precise.inclusiveEnd.addingTimeInterval(86_400)

        return DiveActivityMediaAttachWindow(
            inclusiveStart: min(fetchStart, precise.inclusiveStart),
            inclusiveEnd: max(fetchEnd, precise.inclusiveEnd)
        )
    }

    nonisolated static func resolvedTimeZone(for activity: SnorkelActivity, at referenceInstant: Date? = nil) -> TimeZone {
        let instant = referenceInstant ?? activity.startTime

        if let site = activity.resolvedLinkedSite,
           let identifier = normalizedTimeZoneIdentifier(site.timeZoneIdentifier),
           let timeZone = TimeZone(identifier: identifier) {
            return timeZone
        }

        if let site = activity.resolvedLinkedSite,
           let offset = DiveSiteTimeZoneResolution.offsetSeconds(for: site, at: instant),
           let timeZone = TimeZone(secondsFromGMT: offset) {
            return timeZone
        }

        if let offset = activity.timeZoneOffsetSeconds,
           let timeZone = TimeZone(secondsFromGMT: offset) {
            return timeZone
        }

        if let entry = activity.entryCoordinate,
           DiveMapCoordinateResolver.isUsable(entry),
           let hours = DiveSiteGeographyTimeZoneInference.uddfHoursFromUTC(
               latitude: entry.latitude,
               longitude: entry.longitude,
               at: instant
           ) {
            let offset = DiveDateTimeParsing.uddfTimeZoneHoursToOffsetSeconds(hours)
            if let timeZone = TimeZone(secondsFromGMT: offset) {
                return timeZone
            }
        }

        return TimeZone(secondsFromGMT: 0) ?? .gmt
    }

    private nonisolated static func normalizedTimeZoneIdentifier(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum SnorkelLibraryMediaAutoAttachScheduler: Sendable {
    @MainActor
    static func attachAfterSnorkelPersisted(
        _ activity: SnorkelActivity,
        ownerProfileID: UUID,
        modelContext: ModelContext,
        attachMediaFromPhotoLibrary: Bool? = nil
    ) async {
        let shouldAttach = attachMediaFromPhotoLibrary ?? AppUserSettings.autoUploadMediaToActivities
        guard shouldAttach else { return }
        _ = await SnorkelLibraryMediaAutoAttach.attachMatchingLibraryMedia(
            for: activity,
            ownerProfileID: ownerProfileID,
            modelContext: modelContext,
            requiresAutoUploadSetting: attachMediaFromPhotoLibrary == nil
        )
    }
}
