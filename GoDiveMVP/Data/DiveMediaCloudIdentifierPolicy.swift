import Foundation

/// Normalized storage helpers for **`DiveMediaPhoto.photosCloudIdentifier`**.
enum DiveMediaCloudIdentifierStorage: Sendable {
    nonisolated static func normalized(_ raw: String?) -> String {
        raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    nonisolated static func isPresent(_ raw: String?) -> Bool {
        !normalized(raw).isEmpty
    }
}

/// Outcomes for CloudKit / Photos cloud → local identifier mapping.
enum DiveMediaCloudResolveOutcome: Equatable, Sendable {
    case resolved(localIdentifier: String)
    case notFound
    case ambiguous(localIdentifiers: [String])
    case unavailable
    case emptyInput
}

/// Pure prune / resolve gates (testable without PhotoKit).
enum DiveMediaCloudIdentifierPolicy: Sendable {
    /// Capture / resolve should run when we have a local ID but no synced cloud ID yet.
    nonisolated static func needsCloudIdentifierCapture(
        localIdentifier: String?,
        cloudIdentifier: String?
    ) -> Bool {
        DiveMediaCloudIdentifierStorage.isPresent(localIdentifier)
            && !DiveMediaCloudIdentifierStorage.isPresent(cloudIdentifier)
    }

    /// Attempt cloud→local mapping when the device-local asset is missing but a cloud ID remains.
    nonisolated static func shouldAttemptCloudResolve(
        localAssetExists: Bool,
        cloudIdentifier: String?
    ) -> Bool {
        !localAssetExists && DiveMediaCloudIdentifierStorage.isPresent(cloudIdentifier)
    }

    /// Prune only when the original is confirmed gone (full auth + missing local, and cloud resolve
    /// either absent or **`notFound`**).
    nonisolated static func shouldPrune(
        hasLocalIdentifier: Bool,
        hasCloudIdentifier: Bool,
        hasFullAuthorization: Bool,
        localAssetExists: Bool,
        cloudResolve: DiveMediaCloudResolveOutcome?
    ) -> Bool {
        guard hasFullAuthorization, !localAssetExists else { return false }
        guard hasLocalIdentifier || hasCloudIdentifier else { return false }
        if hasCloudIdentifier {
            switch cloudResolve {
            case .notFound:
                return true
            case .resolved, .ambiguous, .unavailable, .emptyInput, .none:
                return false
            }
        }
        return hasLocalIdentifier
    }
}
