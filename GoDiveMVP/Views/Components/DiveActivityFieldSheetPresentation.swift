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

    /// Media **Tag marine life** / **Tag buddy** — **large** only; grabber swipe dismisses (no **medium** rest).
    func diveMediaTagPickerSheetPresentation() -> some View {
        presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .appSheetPresentationChrome()
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
