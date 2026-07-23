import SwiftUI

/// Friend invite QR share sheet — detent + layout tokens.
enum FriendInviteShareSheetPresentation: Sendable {
    nonisolated static let qrDisplaySize: CGFloat = 196
}

extension View {
    /// Invite QR sheet: fixed **medium** detent (full half-sheet height, not content-sized).
    func friendInviteShareSheetPresentation() -> some View {
        appSheetPresentationChrome()
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
    }
}
