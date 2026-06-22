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
        let saved = try saveConfirmedSpeciesScientificNames([scientificName], on: media, modelContext: modelContext)
        guard let first = saved.first else {
            throw DiveMediaFishialIdentificationStorageError.emptySpeciesName
        }
        return first
    }

    @discardableResult
    static func saveConfirmedSpeciesScientificNames(
        _ scientificNames: [String],
        on media: DiveMediaPhoto,
        modelContext: ModelContext
    ) throws -> [String] {
        let merged = FishialConfirmedSpeciesPresentation.mergedScientificNames(
            existingStoredValue: media.fishialConfirmedSpeciesName,
            adding: scientificNames
        )
        guard !merged.isEmpty else {
            throw DiveMediaFishialIdentificationStorageError.emptySpeciesName
        }
        let storedValue = FishialConfirmedSpeciesPresentation.storageValue(for: merged)
        guard media.fishialConfirmedSpeciesName != storedValue else { return merged }
        media.fishialConfirmedSpeciesName = storedValue
        try modelContext.save()
        DiveActivityMediaStorage.postMediaDidChange()
        return merged
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
        let saved = try saveConfirmedCatalogMatches(
            [option],
            marineLifeByUUID: [marineLife.uuid: marineLife],
            media: media,
            dive: dive,
            captureContext: captureContext,
            owner: owner,
            modelContext: modelContext
        )
        guard let first = saved.first else {
            throw DiveMediaFishialIdentificationStorageError.emptySpeciesName
        }
        return first
    }

    @discardableResult
    static func saveConfirmedCatalogMatches(
        _ options: [FishialCatalogReviewOption],
        marineLifeByUUID: [String: MarineLife],
        media: DiveMediaPhoto,
        dive: DiveActivity,
        captureContext: DiveMediaCaptureContext?,
        owner: UserProfile,
        modelContext: ModelContext
    ) throws -> [String] {
        guard !options.isEmpty else {
            throw DiveMediaFishialIdentificationStorageError.emptySpeciesName
        }

        var commonNames: [String] = []
        var scientificNames: [String] = []

        for option in options {
            guard let marineLife = marineLifeByUUID[option.marineLifeUUID] else {
                throw DiveMediaFishialIdentificationStorageError.missingCatalogSpecies
            }
            _ = try MarineLifeSightingRecorder.tagSpecies(
                marineLife,
                on: media,
                dive: dive,
                captureContext: captureContext,
                owner: owner,
                modelContext: modelContext
            )
            commonNames.append(marineLife.commonName)
            scientificNames.append(option.catalogScientificName)
        }

        _ = try saveConfirmedSpeciesScientificNames(scientificNames, on: media, modelContext: modelContext)
        return commonNames
    }
}

enum DiveMediaFishialIdentificationStorageError: Error, Equatable, Sendable {
    case emptySpeciesName
    case missingSignedInProfile
    case missingCatalogSpecies
}

extension DiveMediaFishialIdentificationStorageError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptySpeciesName:
            return "Choose a species name before saving."
        case .missingSignedInProfile:
            return "Sign in to tag marine life."
        case .missingCatalogSpecies:
            return "Could not find that species in the catalog."
        }
    }
}
