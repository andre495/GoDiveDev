import Foundation

/// Progress updates while Fishial stills are prepared or a selected frame is analyzed.
struct FishialIdentifyProgress: Equatable, Sendable {
    var stage: String
    var completedFrames: Int
    var totalFrames: Int

    nonisolated static func loadingMedia() -> Self {
        Self(stage: "Loading media…", completedFrames: 0, totalFrames: 0)
    }

    nonisolated static func exportingSelectedStill() -> Self {
        Self(stage: "Capturing selected still…", completedFrames: 0, totalFrames: 0)
    }

    nonisolated static func recognizingSelectedFrame() -> Self {
        Self(stage: "Sending to Fishial…", completedFrames: 0, totalFrames: 0)
    }

    nonisolated var progressFraction: Double? {
        guard totalFrames > 0 else { return nil }
        return Double(completedFrames) / Double(totalFrames)
    }
}

#if canImport(UIKit)
import UIKit

/// One exported JPEG still sent to Fishial after user confirmation.
struct FishialIdentifyCandidateFrame: Equatable {
    let data: Data
    let filename: String
    let previewImage: UIImage

    static func == (lhs: FishialIdentifyCandidateFrame, rhs: FishialIdentifyCandidateFrame) -> Bool {
        lhs.data == rhs.data && lhs.filename == rhs.filename
    }
}
#endif

/// Prepares still selection and runs Fishial on the user-chosen frame only.
enum DiveMediaFishialIdentification {

    struct Outcome: Equatable, Sendable {
        let selectedFilename: String
        let observationCoordinate: DiveCoordinate?
        let rankedSpecies: [FishialRecognitionPresentation.RankedSpecies]
        let detectedFishCount: Int
        let species: [FishialSpeciesMatch]
    }

    enum SelectionContext {
        #if canImport(UIKit) && canImport(AVFoundation)
        case video(FishialVideoScrubContext)
        #endif
        #if canImport(UIKit)
        case photo(FishialIdentifyCandidateFrame)
        #endif
    }

    #if canImport(UIKit)
    @MainActor
    static func prepareSelection(for media: DiveMediaPhoto) async throws -> SelectionContext {
        switch media.resolvedMediaKind {
        case .image:
            let frame = try await DiveMediaFishialFrameExport.exportPhotoCandidate(for: media)
            return .photo(frame)
        case .video:
            #if canImport(AVFoundation)
            let context = try await DiveMediaFishialFrameExport.makeVideoScrubContext(for: media)
            return .video(context)
            #else
            throw DiveMediaFishialFrameExportError.assetUnavailable
            #endif
        }
    }

    @MainActor
    static func exportSelectedVideoFrame(
        context: FishialVideoScrubContext,
        atFraction fraction: Double,
        onProgress: @escaping @MainActor (FishialIdentifyProgress) -> Void
    ) async throws -> FishialIdentifyCandidateFrame {
        onProgress(.exportingSelectedStill())
        await Task.yield()
        return try await context.exportCandidateFrame(atFraction: fraction)
    }

    @MainActor
    static func recognizeSelectedFrame(
        _ frame: FishialIdentifyCandidateFrame,
        dive: DiveActivity,
        catalogSites: [DiveSite],
        onProgress: @escaping @MainActor (FishialIdentifyProgress) -> Void
    ) async throws -> Outcome {
        guard !GoDiveUITestConfiguration.isActive else {
            throw FishialAPIError.missingCredentials
        }
        guard let client = FishialAPIClient() else {
            throw FishialAPIError.missingCredentials
        }

        onProgress(.recognizingSelectedFrame())
        await Task.yield()

        let observationCoordinate = FishialObservationLocation.resolvedCoordinate(
            for: dive,
            catalogSites: catalogSites
        )
        let response = try await client.recognizeJPEG(
            frame.data,
            observationCoordinate: observationCoordinate
        )
        let rankedSpecies = FishialRecognitionPresentation.rankedSpecies(from: response)
        let species = FishialRecognitionPresentation.speciesMatches(from: response)

        return Outcome(
            selectedFilename: frame.filename,
            observationCoordinate: observationCoordinate,
            rankedSpecies: rankedSpecies,
            detectedFishCount: response.objects.count,
            species: species
        )
    }
    #endif
}
