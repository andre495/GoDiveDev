import SwiftUI

extension View {
    /// Native sheet chrome for Trip Planner add / edit forms (**medium** only).
    func tripPlannerAddSheetPresentation() -> some View {
        presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .appSheetPresentationChrome()
            .presentationContentInteraction(.scrolls)
    }
}
