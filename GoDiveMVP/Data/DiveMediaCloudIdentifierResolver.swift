import Foundation
#if canImport(Photos)
import Photos
#endif

/// PhotoKit **`PHCloudIdentifier`** encode / decode for **`DiveMediaPhoto.photosCloudIdentifier`**.
enum DiveMediaCloudIdentifierCodec: Sendable {
    #if canImport(Photos)
    nonisolated static func encode(_ identifier: PHCloudIdentifier) -> String {
        DiveMediaCloudIdentifierStorage.normalized(identifier.stringValue)
    }

    nonisolated static func decode(_ raw: String) -> PHCloudIdentifier? {
        let trimmed = DiveMediaCloudIdentifierStorage.normalized(raw)
        guard !trimmed.isEmpty else { return nil }
        return PHCloudIdentifier(stringValue: trimmed)
    }
    #endif
}

/// Maps Photos local ↔ cloud identifiers for cross-device dive media pointers.
enum DiveMediaCloudIdentifierResolver: Sendable {

    /// Best-effort local → cloud string for persistence at attach time.
    nonisolated static func cloudIdentifierString(forLocalIdentifier localIdentifier: String) -> String? {
        #if canImport(Photos)
        let trimmed = DiveMediaCloudIdentifierStorage.normalized(localIdentifier)
        guard !trimmed.isEmpty else { return nil }
        let map = PHPhotoLibrary.shared().cloudIdentifierMappings(forLocalIdentifiers: [trimmed])
        guard let result = map[trimmed] else { return nil }
        switch result {
        case .success(let cloud):
            let encoded = DiveMediaCloudIdentifierCodec.encode(cloud)
            return encoded.isEmpty ? nil : encoded
        case .failure:
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Cloud → local mapping for Device B after CloudKit imports a media pointer.
    nonisolated static func localIdentifier(
        forCloudIdentifierString raw: String
    ) -> DiveMediaCloudResolveOutcome {
        #if canImport(Photos)
        guard let cloud = DiveMediaCloudIdentifierCodec.decode(raw) else {
            return DiveMediaCloudIdentifierStorage.isPresent(raw) ? .unavailable : .emptyInput
        }
        let map = PHPhotoLibrary.shared().localIdentifierMappings(for: [cloud])
        guard let result = map[cloud] else { return .unavailable }
        switch result {
        case .success(let localID):
            let trimmed = DiveMediaCloudIdentifierStorage.normalized(localID)
            return trimmed.isEmpty ? .notFound : .resolved(localIdentifier: trimmed)
        case .failure(let error):
            return outcome(forPhotoKitError: error)
        }
        #else
        return .unavailable
        #endif
    }

    #if canImport(Photos)
    nonisolated static func outcome(forPhotoKitError error: Error) -> DiveMediaCloudResolveOutcome {
        let nsError = error as NSError
        if nsError.domain == PHPhotosErrorDomain {
            switch PHPhotosError.Code(rawValue: nsError.code) {
            case .identifierNotFound:
                return .notFound
            case .multipleIdentifiersFound:
                // Prefer a deterministic first identifier when PhotoKit surfaces multiples.
                if let identifiers = nsError.userInfo[PHLocalIdentifiersErrorKey] as? [String] {
                    let trimmed = identifiers
                        .map(DiveMediaCloudIdentifierStorage.normalized)
                        .filter { !$0.isEmpty }
                    if trimmed.count == 1 {
                        return .resolved(localIdentifier: trimmed[0])
                    }
                    if !trimmed.isEmpty {
                        return .ambiguous(localIdentifiers: trimmed)
                    }
                }
                return .ambiguous(localIdentifiers: [])
            default:
                return .unavailable
            }
        }
        return .unavailable
    }
    #endif
}
