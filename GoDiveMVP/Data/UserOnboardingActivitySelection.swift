import Foundation

/// Water activities chosen during logged-out onboarding — persisted on the profile at sign-in.
struct UserOnboardingActivitySelection: Hashable, Sendable {
    var doesScubaDiving: Bool
    var doesFreeDiving: Bool
    var doesSnorkeling: Bool

    nonisolated static let empty = UserOnboardingActivitySelection(
        doesScubaDiving: false,
        doesFreeDiving: false,
        doesSnorkeling: false
    )

    /// Welcome screen default — scuba pre-selected so **Show me around** is enabled immediately.
    nonisolated static let welcomeDefault = UserOnboardingActivitySelection(
        doesScubaDiving: true,
        doesFreeDiving: false,
        doesSnorkeling: false
    )

    nonisolated static let pendingUserDefaultsKey = "goDivePendingOnboardingActivities"

    nonisolated var hasAnySelection: Bool {
        doesScubaDiving || doesFreeDiving || doesSnorkeling
    }

    nonisolated func contains(_ kind: UserOnboardingActivityKind) -> Bool {
        switch kind {
        case .scubaDiving: doesScubaDiving
        case .freeDiving: doesFreeDiving
        case .snorkeling: doesSnorkeling
        }
    }

    nonisolated mutating func toggle(_ kind: UserOnboardingActivityKind) {
        switch kind {
        case .scubaDiving: doesScubaDiving.toggle()
        case .freeDiving: doesFreeDiving.toggle()
        case .snorkeling: doesSnorkeling.toggle()
        }
    }

    nonisolated static func loadPending(userDefaults: UserDefaults = .standard) -> UserOnboardingActivitySelection? {
        guard let data = userDefaults.data(forKey: pendingUserDefaultsKey) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Bool] else {
            return nil
        }
        return UserOnboardingActivitySelection(
            doesScubaDiving: object[Keys.doesScubaDiving] ?? false,
            doesFreeDiving: object[Keys.doesFreeDiving] ?? false,
            doesSnorkeling: object[Keys.doesSnorkeling] ?? false
        )
    }

    nonisolated static func savePending(
        _ selection: UserOnboardingActivitySelection,
        userDefaults: UserDefaults = .standard
    ) {
        let object: [String: Bool] = [
            Keys.doesScubaDiving: selection.doesScubaDiving,
            Keys.doesFreeDiving: selection.doesFreeDiving,
            Keys.doesSnorkeling: selection.doesSnorkeling,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        userDefaults.set(data, forKey: pendingUserDefaultsKey)
    }

    private enum Keys {
        nonisolated static let doesScubaDiving = "doesScubaDiving"
        nonisolated static let doesFreeDiving = "doesFreeDiving"
        nonisolated static let doesSnorkeling = "doesSnorkeling"
    }

    nonisolated static func clearPending(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: pendingUserDefaultsKey)
    }
}

/// Activities offered on the logged-out welcome screen.
enum UserOnboardingActivityKind: String, CaseIterable, Identifiable, Sendable {
    case scubaDiving
    case freeDiving
    case snorkeling

    var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .scubaDiving: "Scuba Diving"
        case .freeDiving: "Free Diving"
        case .snorkeling: "Snorkeling"
        }
    }

    nonisolated var subtitle: String {
        switch self {
        case .scubaDiving: "Tank dives, profiles, and gas"
        case .freeDiving: "Breath-hold depth and sessions"
        case .snorkeling: "Surface swims and sightings"
        }
    }

    nonisolated var assetImageName: String? {
        switch self {
        case .scubaDiving: "ScubaTankTab"
        case .freeDiving, .snorkeling: nil
        }
    }

    nonisolated var systemImage: String? {
        switch self {
        case .scubaDiving: nil
        case .freeDiving: "water.waves.and.arrow.down"
        case .snorkeling: "figure.water.fitness"
        }
    }

    nonisolated var accessibilityIdentifier: String {
        "LoggedOutOnboarding.Activity.\(rawValue)"
    }
}
