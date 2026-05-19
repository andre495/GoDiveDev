import SwiftUI

extension View {
    /// Native sheet chrome for certification add / edit forms.
    func certificationAddSheetPresentation() -> some View {
        presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .appSheetPresentationChrome()
            .presentationContentInteraction(.scrolls)
    }
}
