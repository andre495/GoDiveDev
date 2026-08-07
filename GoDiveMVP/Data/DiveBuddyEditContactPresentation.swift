import Foundation

/// Contact-link actions on **`DiveBuddyEditSheetView`** (local non-GoDive buddies).
enum DiveBuddyEditContactPresentation: Sendable {
    nonisolated static let sectionTitle = "Contact"

    nonisolated static func linkButtonTitle(isLinked: Bool) -> String {
        isLinked ? "Change contact" : "Connect to Contact"
    }

    nonisolated static let disconnectButtonTitle = "Disconnect contact"

    nonisolated static let linkAccessibilityIdentifier = "DiveBuddyEditSheet.ContactLink"
    nonisolated static let disconnectAccessibilityIdentifier = "DiveBuddyEditSheet.ContactDisconnect"
}
