import Foundation

/// Fast local session restore inputs — no network, no full-store scans.
enum AppLaunchSessionRestorePresentation: Sendable {
    nonisolated static let currentProfileIDUserDefaultsKey = "goDiveCurrentProfileID"

    nonisolated static func persistedProfileID(storedUUIDString: String?) -> UUID? {
        guard let storedUUIDString, let id = UUID(uuidString: storedUUIDString) else { return nil }
        return id
    }
}
