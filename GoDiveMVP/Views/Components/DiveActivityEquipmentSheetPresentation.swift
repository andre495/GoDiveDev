import SwiftUI

extension View {
    /// Native sheet chrome for **Tank** tab add-equipment picker.
    func diveActivityAddEquipmentSheetPresentation() -> some View {
        presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .appSheetPresentationChrome()
            .presentationContentInteraction(.scrolls)
    }
}
