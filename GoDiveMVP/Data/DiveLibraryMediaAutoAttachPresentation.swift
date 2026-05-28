import Foundation

/// Copy and overlay state for **Settings → Auto-upload media** backfill.
enum DiveLibraryMediaAutoAttachPresentation: Sendable {

    static let overlayTitle = "Matching photos to dives"

    nonisolated static let stageRequestingAccess = "Requesting Photos access…"
    nonisolated static let stageNoDives = "No dives in your log."
    nonisolated static let stageLoadLogFailed = "Could not load your log."

    nonisolated static func stageCheckingDive(diveIndex: Int, diveCount: Int) -> String {
        guard diveCount > 0 else { return "Matching photos to dives…" }
        return "Checking dive \(diveIndex) of \(diveCount)…"
    }

    nonisolated static func stageMatchingPhotosInDive(processed: Int, total: Int) -> String {
        guard total > 0 else { return "Matching photos…" }
        return "Matching \(processed) of \(total) in this dive…"
    }

    nonisolated static func progressFraction(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return min(max(Double(completed) / Double(total), 0), 1)
    }

    nonisolated static func countLabel(completed: Int, total: Int) -> String {
        guard total > 0 else { return "" }
        return "\(completed) of \(total)"
    }

    nonisolated static func finishedMessage(for outcome: DiveLibraryMediaAutoAttach.Outcome) -> String {
        if outcome.authorizationDenied {
            return "Photos access is required to match library media to your dives. You can allow access in Settings → Privacy → Photos."
        }
        if outcome.attachedCount == 0 {
            if outcome.skippedAlreadyLinked > 0 {
                return "No new photos were added. Matching items are already on your dives."
            }
            return "No photos or videos in your library matched your dive times."
        }
        let noun = outcome.attachedCount == 1 ? "item" : "items"
        return "Attached \(outcome.attachedCount) \(noun) from your library."
    }

    nonisolated static let authorizationDeniedTitle = "Photos access needed"
    nonisolated static let finishedTitle = "Photo matching complete"
    nonisolated static let cancelledMessage = "Matching stopped. Photos added so far were kept on your dives."
}

enum DiveLibraryMediaBackfillOverlayState: Equatable {
    case hidden
    case running(completed: Int, total: Int, stage: String)
    case finished(DiveLibraryMediaAutoAttach.Outcome)
    case cancelled

    var isVisible: Bool {
        if case .hidden = self { return false }
        return true
    }
}
