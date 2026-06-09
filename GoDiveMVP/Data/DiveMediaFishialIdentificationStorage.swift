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
}

enum DiveMediaFishialIdentificationStorageError: Error, Equatable, Sendable {
    case emptySpeciesName
}

extension DiveMediaFishialIdentificationStorageError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptySpeciesName:
            return "Choose a species name before saving."
        }
    }
}
