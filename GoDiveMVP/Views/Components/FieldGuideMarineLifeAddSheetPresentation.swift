import SwiftUI

extension View {
    func fieldGuideMarineLifeAddSheetPresentation() -> some View {
        presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .appSheetPresentationChrome()
            .presentationContentInteraction(.scrolls)
    }
}
