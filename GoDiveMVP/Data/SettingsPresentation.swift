import Foundation

/// Copy for **Settings** rows (testable without SwiftUI).
enum SettingsPresentation: Sendable {

    enum ImperialUnits {
        nonisolated static let title = "Imperial units"
        nonisolated static let infoMessage =
            "When on, depths show in feet, water temperature in °F, cylinder pressure in psi, and tank volume in cubic feet. Off uses metric (meters, °C, bar, liters). Imported values are always stored the same way; this only changes how numbers appear."
    }

    enum DefaultTank {
        nonisolated static let title = "Default tank"
        nonisolated static let infoMessage =
            "Used for new imports and gas details when a dive file does not specify cylinder size or material. Existing dives keep their stored values until re-imported."
    }

    enum AutomaticallyRenumberDives {
        nonisolated static let title = "Automatically renumber dives"
        nonisolated static let infoMessage =
            "When on, dive numbers stay 1, 2, 3, … in chronological order whenever you import a dive or delete one. When off, numbers are not adjusted after a delete (imports still get the next number in the existing chain). Dives marked with no number (-) in Details are assigned a number when this runs."
    }

    enum AutoUploadMediaToActivities {
        nonisolated static let title = "Auto-upload media to activities"
        nonisolated static let infoMessage =
            "When on, GoDive reads your Apple Photos library (with your permission) and attaches photos and videos whose capture time falls within each dive’s start and end window. Turning this on scans dives already in your log; new imports are matched automatically. Media stays on your device in GoDive only — nothing is uploaded to a server. With Limited Photos access, only photos you allow are visible to the app."
    }

    nonisolated static func infoAccessibilityLabel(forSettingTitle title: String) -> String {
        "More information about \(title)"
    }
}
