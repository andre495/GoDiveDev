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

    /// Prune when the original is confirmed gone under **full** Photos authorization.
    ///
    /// When a cloud ID is present, the caller must attempt resolve first. **`nil`** cloudResolve means
    /// “not attempted yet” → do not prune. After a resolve attempt, **`notFound`** / **`resolved`** /
    /// **`ambiguous`** with **`localAssetExists == false`** means the Photos original is gone (including
    /// reinstall after the user deleted the photo) → prune. **`unavailable`** keeps the row.
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
            case .notFound, .resolved, .ambiguous:
                return true
            case .unavailable, .emptyInput, .none:
                return false
            }
        }
        return hasLocalIdentifier
    }
}
