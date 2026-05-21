import Foundation

/// Copy and progress math for the dive **Media** add overlay.
enum DiveMediaImportProgressPresentation: Sendable {
    static func progressFraction(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(min(max(0, completed), total)) / Double(total)
    }

    static func loadingStage(itemIndex: Int, total: Int) -> String {
        "Loading \(itemIndex) of \(total)…"
    }

    static func savingStage(itemIndex: Int, total: Int) -> String {
        "Saving \(itemIndex) of \(total)…"
    }

    static func countLabel(completed: Int, total: Int) -> String {
        "\(min(completed, total)) of \(total) added"
    }

    static func failureMessageWhenNoneSaved(attempted: Int) -> String {
        if attempted == 1 {
            return "Could not add the selected item. Try a different photo or video."
        }
        return "Could not add any of the selected items. Try different photos or videos."
    }
}

enum DiveMediaImportOverlayState: Equatable {
    case hidden
    case importing(completed: Int, total: Int, stage: String)
    case failed(String)

    var isBlocking: Bool {
        switch self {
        case .hidden: return false
        case .importing, .failed: return true
        }
    }
}
