import SwiftUI

extension View {
    func diveSiteAddSheetPresentation() -> some View {
        presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .appSheetPresentationChrome()
    }
}
