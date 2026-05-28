import SwiftUI

extension View {
    func diveActivityFieldSheetPresentation() -> some View {
        presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .appSheetPresentationChrome()
    }

    /// Dive field sheets that should open expanded (e.g. tags picker).
    func diveActivityTagsSheetPresentation() -> some View {
        modifier(DiveActivityTagsSheetPresentationModifier())
    }
}

private struct DiveActivityTagsSheetPresentationModifier: ViewModifier {
    @State private var selectedDetent: PresentationDetent = .large

    func body(content: Content) -> some View {
        content
            .presentationDetents([.medium, .large], selection: $selectedDetent)
            .presentationDragIndicator(.visible)
            .appSheetPresentationChrome()
    }
}
