import SwiftUI

extension View {
    /// Native sheet chrome for the Trip Planner add-trip form.
    func tripPlannerAddSheetPresentation() -> some View {
        presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .appSheetPresentationChrome()
            .presentationContentInteraction(.scrolls)
    }
}
