import SwiftUI

extension View {
    func diveActivityFieldSheetPresentation() -> some View {
        presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .appSheetPresentationChrome()
    }
}
