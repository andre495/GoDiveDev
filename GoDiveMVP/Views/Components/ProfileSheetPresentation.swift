import SwiftUI

extension View {
    func profileEditSheetPresentation() -> some View {
        presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .appSheetContentTopSpacing()
    }
}
