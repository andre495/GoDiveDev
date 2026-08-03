import Foundation

/// Per-activity notes sharing mode for the buddy network.
enum ActivityFriendShareNotesMode: String, Sendable, CaseIterable, Identifiable {
    case off
    case privateNotes
    case publicNotes

    var id: String { rawValue }

    nonisolated var settingsLabel: String {
        switch self {
        case .off: return "Off"
        case .privateNotes: return "Share private notes"
        case .publicNotes: return "Share public note"
        }
    }
}
