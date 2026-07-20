import Foundation
import SwiftData

/// Coordinates FIT/UDDF import: decode + persist stay on the UI model context (Swift 6 default
/// **MainActor** isolation), while geocode prefetch and OpenDiveMap indexing keep bulk imports fast.
/// PhotoKit / Contacts attach remain the caller’s responsibility when using the low-level persist APIs.
enum DiveBackgroundImportCoordinator {

    /// Yield UI progress every N dives.
    static let progressYieldStride = 10

    @MainActor
    static func importUddf(
        data: Data,
        modelContext: ModelContext,
        owner: UserProfile,
        createMissingDiveSites: Bool,
        attachMediaFromPhotoLibrary: Bool? = nil,
        onProgress: UddfDiveFileImport.ProgressHandler? = nil,
        onMediaAttachProgress: DiveLibraryMediaAutoAttach.ProgressHandler? = nil
    ) async -> DiveFileImportOutcome {
        do {
            let activities = try UddfDiveFileDecoder.buildDiveActivities(from: data)
            return await UddfDiveFileImport.persistImportedActivities(
                activities,
                modelContext: modelContext,
                owner: owner,
                createMissingDiveSites: createMissingDiveSites,
                attachMediaFromPhotoLibrary: attachMediaFromPhotoLibrary,
                onProgress: onProgress,
                onMediaAttachProgress: onMediaAttachProgress
            )
        } catch let uddf as UddfDecodeError {
            GoDiveUserFacingError.recordImportRejection(uddf)
            return DiveFileImportOutcome(
                userMessage: GoDiveUserFacingError.importUserMessage(for: uddf),
                primaryInsertedDiveId: nil
            )
        } catch {
            GoDiveUserFacingError.recordImportRejection(error)
            return DiveFileImportOutcome(
                userMessage: GoDiveUserFacingError.importUserMessage(for: error),
                primaryInsertedDiveId: nil
            )
        }
    }

    @MainActor
    static func importFit(
        data: Data,
        modelContext: ModelContext,
        owner: UserProfile,
        createMissingDiveSites: Bool,
        attachMedia: Bool
    ) async -> DiveFileImportOutcome {
        do {
            let activity = try FitDiveFileDecoder.buildDiveActivity(from: data)
            return await FitDiveFileImport.persistImportedActivity(
                activity,
                modelContext: modelContext,
                owner: owner,
                attachMedia: attachMedia,
                createMissingDiveSites: createMissingDiveSites
            )
        } catch let fit as FitDecodeError {
            GoDiveUserFacingError.recordImportRejection(fit)
            return DiveFileImportOutcome(
                userMessage: GoDiveUserFacingError.importUserMessage(for: fit),
                primaryInsertedDiveId: nil
            )
        } catch {
            GoDiveUserFacingError.recordImportRejection(error)
            return DiveFileImportOutcome(
                userMessage: GoDiveUserFacingError.importUserMessage(for: error),
                primaryInsertedDiveId: nil
            )
        }
    }
}