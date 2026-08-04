import Foundation

/// Per-activity notes sharing mode for the buddy network.
enum ActivityFriendShareNotesMode: String, Sendable, CaseIterable, Identifiable {
    case off
    case privateNotes
    /// Legacy mode (separate buddy-only note). Settings UI maps this to the private-notes toggle.
    case publicNotes

    var id: String { rawValue }

    nonisolated var settingsLabel: String {
        switch self {
        case .off: return "Off"
        case .privateNotes: return "Share private notes"
        case .publicNotes: return "Share public note"
        }
    }

    /// Activity Settings toggle — on when any notes mode is active (including legacy public notes).
    nonisolated var sharePrivateNotesToggleIsOn: Bool {
        switch self {
        case .off: return false
        case .privateNotes, .publicNotes: return true
        }
    }

    /// Maps the Activity Settings private-notes toggle onto a persisted mode.
    nonisolated static func fromSharePrivateNotesToggle(_ isOn: Bool) -> ActivityFriendShareNotesMode {
        isOn ? .privateNotes : .off
    }
}
