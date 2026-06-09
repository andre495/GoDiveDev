import Foundation
import SwiftData

/// Persists user-confirmed Fishial species names on **`DiveMediaPhoto`** rows.
enum DiveMediaFishialIdentificationStorage {

    @discardableResult
    static func saveConfirmedSpecies(
        _ scientificName: String,
        on media: DiveMediaPhoto,
        modelContext: ModelContext
    ) throws -> String {
        let trimmed = scientificName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DiveMediaFishialIdentificationStorageError.emptySpeciesName
        }
        guard media.fishialConfirmedSpeciesName != trimmed else { return trimmed }
        media.fishialConfirmedSpeciesName = trimmed
        try modelContext.save()
        DiveActivityMediaStorage.postMediaDidChange()
        return trimmed
    }

    @discardableResult
    static func saveConfirmedCatalogMatch(
        _ option: FishialCatalogReviewOption,
        marineLife: MarineLife,
        media: DiveMediaPhoto,
        dive: DiveActivity,
        captureContext: DiveMediaCaptureContext?,
        owner: UserProfile,
        modelContext: ModelContext
    ) throws -> String {
        _ = try MarineLifeSightingRecorder.tagSpecies(
            marineLife,
            on: media,
            dive: dive,
            captureContext: captureContext,
            owner: owner,
            modelContext: modelContext
        )
        _ = try saveConfirmedSpecies(option.catalogScientificName, on: media, modelContext: modelContext)
        return marineLife.commonName
    }
}

enum DiveMediaFishialIdentificationStorageError: Error, Equatable, Sendable {
    case emptySpeciesName
    case missingSignedInProfile
}

extension DiveMediaFishialIdentificationStorageError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptySpeciesName:
            return "Choose a species name before saving."
        case .missingSignedInProfile:
            return "Sign in to tag marine life."
        }
    }
}
