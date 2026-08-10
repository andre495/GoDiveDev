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

    /// Opaque blue overview-panel modal (notes / buddies / tags / comments / dive conditions).
    /// System **`.large`** only so iOS 26 edge-attaches the sheet (partial-height detents float
    /// with a bottom gap). No grabber; dismiss only via toolbar actions.
    func diveActivityOverviewPanelModalSheetPresentation() -> some View {
        modifier(DiveActivityOverviewPanelModalSheetPresentationModifier())
    }

    /// Media **Tag marine life** — same blue overview-panel modal as notes / buddies.
    func diveMediaTagPickerSheetPresentation() -> some View {
        diveActivityOverviewPanelModalSheetPresentation()
    }
}

/// Presentation tokens for blue overview-panel modals (comments, notes, buddies, …).
enum DiveActivityOverviewPanelModalPresentation: Sendable {
    /// System **`.large`** — edge-attached on iOS 26 (covers the bottom screen edge).
    nonisolated static var presentationDetents: Set<PresentationDetent> { [.large] }
}

private struct DiveActivityOverviewPanelModalSheetPresentationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationDetents(DiveActivityOverviewPanelModalPresentation.presentationDetents)
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
