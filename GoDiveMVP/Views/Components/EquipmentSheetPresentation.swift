import SwiftUI

extension View {
    /// Native sheet chrome for **Equipment Locker** add / edit forms.
    func equipmentAddSheetPresentation() -> some View {
        presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .appSheetPresentationChrome()
            .presentationContentInteraction(.scrolls)
    }
}
