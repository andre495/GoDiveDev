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

    /// Opaque blue overview-panel modal (notes / buddies / tags / dive conditions).
    /// Opens at the system **large** detent so it fully covers the ~85% overview panel; no grabber;
    /// dismiss only via toolbar actions.
    func diveActivityOverviewPanelModalSheetPresentation() -> some View {
        modifier(DiveActivityOverviewPanelModalSheetPresentationModifier())
    }

    /// Media **Tag marine life** — same blue overview-panel modal as notes / buddies.
    func diveMediaTagPickerSheetPresentation() -> some View {
        diveActivityOverviewPanelModalSheetPresentation()
    }
}

private struct DiveActivityOverviewPanelModalSheetPresentationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled()
            .presentationCornerRadius(AppTheme.Sheet.cornerRadius)
            .presentationBackground {
                AppOverviewSheetPanelBackground()
                    .ignoresSafeArea(edges: .bottom)
            }
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
