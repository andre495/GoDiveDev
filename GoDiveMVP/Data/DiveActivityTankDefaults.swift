import Foundation

/// User default cylinder (**Settings → Default tank**); used on import, RMV, and gas detail rows.
enum DiveActivityTankDefaults: Sendable {
    nonisolated static let defaultSize: DefaultTankSize = .al80

    nonisolated static func resolvedSpecification(userDefaults: UserDefaults = .standard) -> DefaultTankSpecification {
        let raw = userDefaults.string(forKey: AppUserSettings.defaultTankSizeKey)
        let size = raw.flatMap(DefaultTankSize.init(rawValue:)) ?? defaultSize
        return size.specification
    }
}
